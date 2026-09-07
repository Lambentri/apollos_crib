defmodule RoomGtfs.FeedTester do
  @moduledoc """
  Fetches a source's realtime URLs and says what is wrong with them.

  Every check here exists because the mistake it catches was actually made, and
  because none of them announce themselves. A realtime feed that is wrong does
  not error -- it decodes, reports plausible numbers, and quietly matches
  nothing, and the symptom is "why are there no live times" a week later.

  What it looks for, roughly in order of how long it would otherwise take to
  work out:

    * **Realtime that does not match the static feed.** The worst one. Trip and
      stop ids only mean something against the schedule they came from, and
      511's realtime uses 511's stop numbering while an operator's own download
      uses the operator's. Trips then match, stops do not, and arrivals find the
      trip and no times for it -- a half-working state that looks like a bug in
      the app.

    * **A `.proto` definition configured as a feed.** The MTA publishes both,
      one describes the other, and pasting the wrong one gives a decode failure
      naming a truncated URL.

    * **A prefixed feed with no operator code.** 511's regional feed keys trips
      `SF:12074394_M21`; without `rt_agency` nothing matches, and with the wrong
      one everything is filtered away. Both look identical from the outside: no
      realtime.

    * **An endpoint that answers 200 with an error page**, which several do.

  Read-only, and deliberately not cached: the whole point is to see what the
  URL says right now.
  """

  import Ecto.Query

  alias RoomSanctum.Repo

  # Enough to be confident about a percentage without pulling a whole feed's
  # worth of ids through the database.
  @sample 300

  @doc """
  Test every realtime URL a source has, one entry per distinct URL.

  Returns `[%{url:, kinds:, findings:, ...}]` where `findings` is a list of
  `{severity, message}` with severity in `:error`, `:warn`, `:info`, `:ok`.
  """
  def run(%{type: :gtfs} = source) do
    source.config
    |> RoomGtfs.Worker.RT.rt_groups()
    |> Enum.map(&check_group(&1, source))
  end

  def run(_source), do: []

  defp check_group({url, kinds}, source) do
    base = %{url: display_url(url), kinds: kinds, entities: %{}, findings: []}

    # The source's own headers, because a feed behind an API key answers 403 to
    # a request without one -- and a tester that reports "did not answer with
    # HTTP 200" for a feed the worker fetches perfectly well is worse than no
    # tester at all. It sends what the worker sends, or it is testing something
    # else.
    headers = RoomSanctum.Configuration.Configs.GTFS.request_headers(source.config)

    case RoomGtfs.Worker.RT.fetch_rt_url(url, headers) do
      {:ok, feed} ->
        base
        |> Map.put(:ok, true)
        |> check_contents(feed, kinds, source)

      {:error, reason} ->
        base
        |> Map.put(:ok, false)
        |> add(:error, describe_failure(reason, url))
    end
  end

  defp check_contents(result, feed, kinds, source) do
    counts = %{
      tu: Enum.count(feed.entity, & &1.trip_update),
      vp: Enum.count(feed.entity, & &1.vehicle),
      sa: Enum.count(feed.entity, & &1.alert)
    }

    result
    |> Map.put(:entities, counts)
    |> Map.put(:total, length(feed.entity))
    |> Map.put(:capabilities, capabilities(feed))
    |> check_empty(feed, counts, kinds)
    |> check_incrementality(feed)
    |> check_stop_identification(feed)
    |> check_age(feed)
    |> check_extensions(feed)
    |> check_agency(feed, source)
    |> check_against_static(feed, source)
    |> finish()
  end

  defp check_empty(result, feed, counts, kinds) do
    cond do
      # A differential feed saying nothing has changed since the last poll is a
      # feed working correctly, not an empty one.
      result.total == 0 and differential?(feed) ->
        add(result, :info, "no changes in this delta")

      result.total == 0 ->
        add(result, :warn, "decoded, but carries no entities at all right now")

      Enum.all?(kinds, &(counts[&1] == 0)) ->
        add(
          result,
          :error,
          "carries nothing of the kind it is configured for -- it has " <>
            describe_counts(counts) <> ", but this URL is set as " <> kind_names(kinds)
        )

      true ->
        Enum.reduce(kinds, result, fn kind, acc ->
          if counts[kind] == 0 do
            add(acc, :warn, "no #{kind_name(kind)} in this feed, though it is configured for them")
          else
            acc
          end
        end)
    end
  end

  # A differential feed is a stream of edits to a feed held open, not a
  # snapshot -- so the message in front of you is not the feed, and its entity
  # count says nothing about how much this source is carrying. Worth saying
  # out loud, because every other number on this page is read as a total.
  @doc false
  def check_incrementality(result, feed) do
    deleted = Enum.count(feed.entity, & &1.is_deleted)

    case feed.header && feed.header.incrementality do
      :DIFFERENTIAL ->
        add(
          result,
          :info,
          "differential: each message carries only what changed, and entities are held " <>
            "between polls rather than replaced. What is listed here is this delta" <>
            deleted_note(deleted) <> ", not the whole feed"
        )

      _otherwise when deleted > 0 ->
        add(
          result,
          :warn,
          "#{deleted} entities are marked deleted in a feed that calls itself a full " <>
            "dataset -- a full dataset is already the whole truth, so these say nothing " <>
            "and are being kept"
        )

      _otherwise ->
        result
    end
  end

  defp deleted_note(0), do: ""
  defp deleted_note(1), do: ", one of them a deletion"
  defp deleted_note(n), do: ", #{n} of them deletions"

  # GTFS-RT lets a stop update name its stop by id, by position in the trip, or
  # both. Live arrivals are matched by stop id alone, so a feed that only counts
  # positions matches nothing at all: no live times, no error, no clue. The
  # static schedule is what would have to be consulted to turn a sequence back
  # into a stop, and nothing does that.
  @doc false
  def check_stop_identification(result, feed) do
    stus =
      feed.entity
      |> Enum.filter(& &1.trip_update)
      |> Enum.flat_map(& &1.trip_update.stop_time_update)

    total = length(stus)
    missing = Enum.count(stus, &(&1.stop_id in [nil, ""]))

    cond do
      total == 0 or missing == 0 ->
        result

      missing == total ->
        add(
          result,
          :error,
          "identifies stops only by their position in the trip, never by stop id -- " <>
            "arrivals are matched on stop id, so nothing in this feed will ever match"
        )

      true ->
        add(
          result,
          :warn,
          "#{missing} of #{total} stop updates carry no stop id, only a position in the " <>
            "trip -- those cannot be matched to a stop and are skipped"
        )
    end
  end

  defp differential?(feed) do
    feed.header && feed.header.incrementality == :DIFFERENTIAL
  end

  defp check_age(result, feed) do
    case feed.header && feed.header.timestamp do
      nil ->
        result

      ts ->
        age = System.system_time(:second) - ts

        cond do
          age > 3600 -> add(result, :error, "feed timestamp is #{div(age, 60)} minutes old")
          age > 300 -> add(result, :warn, "feed timestamp is #{div(age, 60)} minutes old")
          true -> result
        end
    end
  end

  defp check_extensions(result, feed) do
    unnamed =
      Enum.reduce(feed.entity, length(feed.header.__unknown_fields__), fn e, acc ->
        acc + length(e.__unknown_fields__) + unknown(e.trip_update) + unknown(e.vehicle) +
          unknown(e.alert)
      end)

    result = Map.put(result, :extensions, unnamed)

    if unnamed > 0 do
      add(
        result,
        :info,
        "#{unnamed} fields no loaded extension can name -- kept, not decoded, and not an error"
      )
    else
      result
    end
  end

  defp unknown(nil), do: 0
  defp unknown(%{__unknown_fields__: fields}), do: length(fields)
  defp unknown(_other), do: 0

  # A feed that names its operators, against a source that may or may not say
  # which one it wants. Skipped for a feed with no trips in it at all -- a
  # service-alerts feed carries none, and asking why it prefixes nothing would
  # report a problem with a perfectly ordinary feed.
  defp check_agency(result, feed, source) do
    if Enum.any?(feed.entity, &(trip_id(&1) != nil)) do
      do_check_agency(result, feed, source)
    else
      result
    end
  end

  defp do_check_agency(result, feed, source) do
    prefixes =
      feed.entity
      |> Enum.map(&trip_id/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn id ->
        case String.split(id, ":", parts: 2) do
          [prefix, _rest] -> prefix
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    configured = Map.get(source.config, :rt_agency)
    result = Map.put(result, :prefixes, prefixes)

    cond do
      prefixes != [] and configured in [nil, ""] ->
        add(
          result,
          :error,
          "trip ids are prefixed (#{Enum.join(Enum.take(prefixes, 6), ", ")}#{if length(prefixes) > 6, do: ", …", else: ""}) " <>
            "but no operator code is set, so nothing will match the schedule"
        )

      configured not in [nil, ""] and prefixes == [] ->
        add(
          result,
          :warn,
          "operator code #{configured} is set but this feed prefixes nothing, so everything will be filtered out"
        )

      configured not in [nil, ""] and configured not in prefixes ->
        add(
          result,
          :error,
          "operator code #{configured} appears nowhere in this feed, which carries " <>
            Enum.join(Enum.take(prefixes, 8), ", ")
        )

      true ->
        result
    end
  end

  # The check worth having. Ids only mean anything against the schedule they
  # came from.
  defp check_against_static(result, feed, source) do
    agency = Map.get(source.config, :rt_agency)

    # Narrowed the way the poller narrows it. Sampling the raw regional feed
    # would draw mostly other operators' entities and report 0% against a
    # perfectly correct source -- which is what it did before this line.
    feed = RoomGtfs.Worker.RT.for_this_agency(feed, %{inst: source})

    trips =
      feed.entity
      |> Enum.map(&trip_id/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&unprefix(&1, agency))
      |> Enum.uniq()
      |> Enum.take(@sample)

    stops =
      feed.entity
      |> Enum.filter(& &1.trip_update)
      |> Enum.flat_map(& &1.trip_update.stop_time_update)
      |> Enum.map(& &1.stop_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.take(@sample)

    result
    |> match_against(:trips, trips, source, &known_trips/2)
    |> match_against(:stops, stops, source, &known_stops/2)
  end

  defp match_against(result, _label, [], _source, _fun), do: result

  defp match_against(result, label, ids, source, fun) do
    known = fun.(source, ids)
    pct = round(known / length(ids) * 100)
    result = Map.put(result, :"#{label}_match", pct)

    cond do
      pct == 0 and label == :trips and partial_trip_ids?(source.id, ids) ->
        add(
          result,
          :error,
          "its trip ids are the tail end of the schedule's -- realtime sends " <>
            "\"098600_5..S03R\" where the schedule says " <>
            "\"ASP26GEN-1038-Sunday-00_098600_5..S03R\". NYCT publishes partial ids like " <>
            "this, and nothing matches on an exact comparison, so there are no live times. " <>
            "Tick \"Realtime sends partial trip ids\" on this offering to match on the tail"
        )

      pct == 0 ->
        add(
          result,
          :error,
          "none of its #{label} exist in this offering's schedule -- realtime and static are from " <>
            "different publishers, or the schedule has not been imported"
        )

      pct < 60 ->
        # Not a fault. One feed often covers more than one offering: MTA's bus
        # realtime is citywide while the schedules are split by borough, so
        # Brooklyn legitimately sees about a third of it and a small borough
        # sees a few percent. The number worth acting on is zero, and warning
        # about the rest would cry wolf at every correctly split source.
        add(
          result,
          :ok,
          "#{pct}% of its #{label} are in this offering's schedule -- expected to be a " <>
            "fraction where one feed serves several offerings, as MTA's citywide bus feed " <>
            "does for the boroughs"
        )

      true ->
        add(result, :ok, "#{pct}% of its #{label} match the schedule")
    end
  end

  # Distinguishes "these ids are from somewhere else entirely" from "these ids
  # are the same ids, shortened" -- which look identical at 0% and are nothing
  # alike to fix.
  defp partial_trip_ids?(source_id, ids) do
    # Patterns built here rather than in SQL: `LIKE ANY(array)` is valid Postgres,
    # `LIKE '%' || ANY(array)` is not -- ANY only compares, it does not
    # concatenate.
    patterns = ids |> Enum.take(40) |> Enum.map(&("%" <> &1))

    matched =
      Repo.one(
        from(t in "gtfs_trips",
          where:
            t.source_id == ^to_int(source_id) and fragment("? LIKE ANY(?)", t.trip_id, ^patterns),
          select: count(t.id)
        )
      ) || 0

    matched > 0
  end

  # Counted the way the poller matches, so a source configured for partial ids is
  # not reported as broken for behaving exactly as configured.
  defp known_trips(source, ids) do
    if Map.get(source.config, :rt_trip_id_suffix) do
      # Counting realtime ids that found a schedule entry, not schedule entries
      # that were found: several scheduled trips share one realtime id across
      # service days, and counting those would read as more than 100%.
      Repo.one(
        from(r in fragment("SELECT unnest(?::text[]) AS id", ^ids),
          where:
            fragment(
              "EXISTS (SELECT 1 FROM gtfs_trips t WHERE t.source_id = ? AND t.trip_id LIKE '%' || ?)",
              ^to_int(source.id),
              r.id
            ),
          select: count()
        )
      ) || 0
    else
      Repo.one(
        from(t in "gtfs_trips",
          where: t.source_id == ^to_int(source.id) and t.trip_id in ^ids,
          select: count(fragment("DISTINCT ?", t.trip_id))
        )
      ) || 0
    end
  end

  defp known_stops(source, ids) do
    Repo.one(
      from(s in "gtfs_stops",
        where: s.source_id == ^to_int(source.id) and s.stop_id in ^ids,
        select: count(fragment("DISTINCT ?", s.stop_id))
      )
    ) || 0
  end

  defp to_int(id) when is_integer(id), do: id
  defp to_int(id) when is_binary(id), do: String.to_integer(id)

  defp trip_id(%{trip_update: %{trip: %{trip_id: id}}}) when is_binary(id), do: id
  defp trip_id(%{vehicle: %{trip: %{trip_id: id}}}) when is_binary(id), do: id
  defp trip_id(_entity), do: nil

  defp unprefix(id, agency) when is_binary(agency) and agency != "",
    do: String.replace_prefix(id, agency <> ":", "")

  defp unprefix(id, _agency), do: id

  defp describe_failure(:not_protobuf, url) do
    if String.ends_with?(url, ".proto") do
      "did not decode as GTFS-realtime, and the URL ends in .proto -- that is the " <>
        "schema describing a feed, not a feed"
    else
      "answered with something that is not GTFS-realtime, most likely an error page"
    end
  end

  defp describe_failure(:decode_failed, url), do: describe_failure(:not_protobuf, url)
  defp describe_failure(:bad_status, _url), do: "did not answer with HTTP 200"
  defp describe_failure(%HTTPoison.Error{reason: reason}, _url), do: "could not be reached: #{inspect(reason)}"
  defp describe_failure(reason, _url), do: "failed: #{inspect(reason)}"

  defp describe_counts(counts) do
    counts
    |> Enum.reject(fn {_k, n} -> n == 0 end)
    |> case do
      [] -> "nothing"
      some -> Enum.map_join(some, ", ", fn {k, n} -> "#{n} #{kind_name(k)}" end)
    end
  end

  defp kind_names(kinds), do: Enum.map_join(kinds, ", ", &kind_name/1)

  defp kind_name(:tu), do: "trip updates"
  defp kind_name(:vp), do: "vehicle positions"
  defp kind_name(:sa), do: "service alerts"

  # Credentials show up in these URLs, and a test result is the kind of thing
  # that gets pasted into a chat window.
  defp display_url(url) do
    Regex.replace(~r/([?&](?:api_key|apikey|key|token)=)([^&]{4})[^&]*/i, url, "\\1\\2****")
  end

  @doc """
  Which optional GTFS-RT fields this feed actually fills in.

  Everything past a trip id and a time is optional in GTFS-RT, and feeds vary
  enormously in how much of it they send -- MBTA populates per-carriage
  occupancy and skipped stops but never a delay or a track assignment; another
  agency does the reverse. Nothing announces this. You find out by building a
  view against a field and seeing an empty column, which is a slow way to learn
  that the feed was never going to say.

  Reported as `%{field => %{present: n, of: total}}` per feed kind, counted over
  what actually arrived rather than declared anywhere. A field nothing reports
  is still listed, with a zero: "this feed does not do that" is the answer
  worth having.
  """
  def capabilities(feed) do
    tus = feed.entity |> Enum.filter(& &1.trip_update) |> Enum.map(& &1.trip_update)
    vps = feed.entity |> Enum.filter(& &1.vehicle) |> Enum.map(& &1.vehicle)
    alerts = feed.entity |> Enum.filter(& &1.alert) |> Enum.map(& &1.alert)
    stus = Enum.flat_map(tus, & &1.stop_time_update)
    events = stus |> Enum.map(&(&1.arrival || &1.departure)) |> Enum.reject(&is_nil/1)
    carriages = Enum.flat_map(vps, &(&1.multi_carriage_details || []))
    informed = Enum.flat_map(alerts, &(&1.informed_entity || []))

    %{}
    |> put_caps(stus, [
      {"live occupancy (per stop)", &set?(&1.departure_occupancy_status)},
      {"skipped stops", &(&1.schedule_relationship == :SKIPPED)},
      {"track assignment", &(&1.stop_time_properties && set?(&1.stop_time_properties.assigned_stop_id))},
      {"per-stop headsign", &(&1.stop_time_properties && set?(&1.stop_time_properties.stop_headsign))}
    ])
    |> put_caps(events, [
      {"delay", &(&1.delay != nil)},
      {"uncertainty", &(&1.uncertainty != nil)}
    ])
    |> put_caps(tus, [
      {"cancelled / added trips", &(&1.trip.schedule_relationship not in [nil, :SCHEDULED])}
    ])
    |> put_caps(vps, [
      {"occupancy", &set?(&1.occupancy_status)},
      {"occupancy %", &(&1.occupancy_percentage != nil and &1.occupancy_percentage >= 0)},
      {"per-carriage occupancy", &(&1.multi_carriage_details != [])},
      {"congestion level", &set?(&1.congestion_level)},
      {"position", &(&1.position != nil)},
      {"bearing", &(&1.position && &1.position.bearing != nil)},
      {"vehicle label", &(&1.vehicle && set?(&1.vehicle.label))}
    ])
    |> put_caps(carriages, [
      {"carriage occupancy", &set?(&1.occupancy_status)}
    ])
    |> put_caps(alerts, [
      {"alert headline", &said?(&1.header_text)},
      {"alert detail", &said?(&1.description_text)},
      {"alert effect", &set?(&1.effect)},
      {"alert cause", &set?(&1.cause)},
      {"alert severity", &set?(&1.severity_level)},
      {"alert period", &(&1.active_period != [])},
      {"alert link", &said?(&1.url)},
      {"alert image", &(&1.image != nil)},
      {"alert audio text", &said?(&1.tts_header_text)}
    ])
    # An alert only reaches a query if it names something the query knows
    # about, and `query_alerts/3` matches on stop, route, or the whole agency.
    # A feed that targets only by route will never raise an alert on a query
    # that is watching one stop of it -- which is a property of the feed, not a
    # bug, and is invisible until you go looking for the alert that never came.
    |> put_caps(informed, [
      {"targets stops", &said_id?(&1.stop_id)},
      {"targets routes", &said_id?(&1.route_id)},
      {"targets trips", &(&1.trip != nil)},
      {"agency-wide", &agency_wide?/1}
    ])
  end

  # An entity naming nothing but an agency -- or naming nothing at all -- is an
  # alert about everything the source carries.
  defp agency_wide?(entity) do
    not said_id?(entity.stop_id) and not said_id?(entity.route_id) and entity.trip == nil and
      entity.route_type == nil
  end

  defp said_id?(id), do: id not in [nil, ""]

  # A translated string is a list of translations, so "present" means it
  # actually carries one with something in it -- an empty envelope is a field
  # the publisher wired up and never filled.
  defp said?(nil), do: false

  defp said?(%{translation: translations}) do
    Enum.any?(translations, &(String.trim(&1.text || "") != ""))
  end

  defp said?(_other), do: false

  # A field only counts as reported when it says something. NO_DATA_AVAILABLE
  # is the feed declining to answer, which is what an absent field means too.
  defp set?(nil), do: false
  defp set?(""), do: false
  defp set?(:NO_DATA_AVAILABLE), do: false
  # The proto defaults for an alert's cause, effect and severity. A field left
  # alone decodes to these, so they mean the publisher said nothing, not that
  # the answer is "unknown".
  defp set?(:UNKNOWN_CAUSE), do: false
  defp set?(:UNKNOWN_EFFECT), do: false
  defp set?(:UNKNOWN_SEVERITY), do: false
  defp set?(_), do: true

  # Counted only where there was something to count: a feed with no vehicles in
  # it has nothing to say about bearings, and listing them all as 0 of 0 would
  # read as a feed that refuses to give them.
  defp put_caps(acc, [], _checks), do: acc

  defp put_caps(acc, items, checks) do
    total = length(items)

    Enum.reduce(checks, acc, fn {label, check}, inner ->
      present = Enum.count(items, fn item -> check.(item) == true end)
      Map.put(inner, label, %{present: present, of: total})
    end)
  end

  defp add(result, severity, message),
    do: Map.update!(result, :findings, &(&1 ++ [{severity, message}]))

  # A group with nothing to say is worth saying so about.
  defp finish(result) do
    if Enum.any?(result.findings, fn {sev, _} -> sev in [:error, :warn] end) do
      result
    else
      add(result, :ok, "looks healthy")
    end
  end
end
