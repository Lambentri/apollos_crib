NimbleCSV.define(XP, separator: ",", escape: "\"")

defmodule RoomGtfs.Worker do
  @moduledoc false
  use Parent.GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus
  # 4 weeks
  @default_refresh_seconds 604_800 * 4

  def start_link(opts) do
    Parent.GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs" <> opts[:name]))
  end

  # Public
  def refresh_db_cfg(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def scheduled_static(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:scheduled_static)
  end

  @doc """
  Ask for a source's static feed to be reimported.

  This queues rather than starts. Every caller — the nightly scheduler and the
  button on the source page both — lands here, and `RoomGtfs.ImportJob` decides
  when the import actually runs; see that module for why. A source that already
  has an import queued or running does not get a second one.
  """
  def update_static_data(name) do
    RoomGtfs.ImportJob.enqueue(name)
  end

  def update_static_data(name, :str) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static_str)
  end

  def update_realtime_data(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_realtime)
  end

  def get_current_realtime(name, trips, stop) do
#    IO.inspect({name, trips, stop})
    "gtfs-rt#{name}"
    |> via_tuple
    |> GenServer.call({:query_realtime, trips, stop}, 30_000)
  end

  def query_alerts(name, stop, route_ids) do
    try do
      "gtfs-rt#{name}"
      |> via_tuple()
      |> GenServer.call({:query_alerts, stop, route_ids}, 10_000)
    catch
      :exit, _ -> []
    end
  end

  @doc """
  Every alert currently in force, unfiltered.

  query_alerts/3 answers "does this affect that stop"; this is the whole feed,
  for looking over what a source is reporting and deciding what is worth a
  query. Returns [] when the worker is not running or no alert feed is set.
  """
  def current_alerts(name) do
    try do
      "gtfs-rt#{name}"
      |> via_tuple()
      |> GenServer.call(:current_alerts, 10_000)
    catch
      :exit, _ -> []
    end
  end

  def get_current_vehicle_positions(name) do
    "gtfs-rt#{name}"
    |> via_tuple
    |> GenServer.call(:query_vehicle_positions, 30_000)
  end

  def get_current_vehicle_positions(name, trips) do
    "gtfs-rt#{name}"
    |> via_tuple
    |> GenServer.call({:query_vehicle_positions, trips}, 30_000)
  end

  def query_stop(id, query) do
    inst = Configuration.get_source!(id)
    res = Storage.get_upcoming_arrivals_for_stop(id, query.stop) |> Storage.fix_arrival_times

    case inst.config.url_rt_tu do
      nil ->
        res

      _val ->
        trips = res |> Enum.map(fn x -> x.trip_id end)

        case get_current_realtime(id, trips, query.stop) do
          [] ->
            res

          rtvals ->
            res
            |> Enum.map(fn x ->
              case Enum.find(rtvals, fn v -> x.trip_id == v.trip_update.trip.trip_id end) do
                nil ->
                  x

                val ->
                  stu = val.trip_update.stop_time_update
                  time_event = stu && (stu.arrival || stu.departure)
                  case time_event do
                    nil ->
                      x

                    event ->
                      x
                      |> Map.put(:arrival_time_live_ts, event.time)
                      |> Map.put(:arrival_time_live_delay, event.delay)
                      |> Map.put(:arrival_time_live_uncertianty, event.uncertainty)
                  end
              end
            end)
        end
    end
  end

  # etc
  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(4),
      run: fn -> RoomGtfs.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(60),
      when: fn -> match?(%Time{hour: 0, minute: 0}, Time.utc_now()) end,
      run: fn -> RoomGtfs.Worker.scheduled_static(opts[:name]) end
    )

    {:ok, child_rt} = Parent.start_child({RoomGtfs.Worker.RT, opts})
    {:ok, child_static} = Parent.start_child({RoomGtfs.Worker.Static, opts})

    {:ok,
     %{
       id: opts[:name],
       inst: nil,
       child_rt: child_rt,
       child_static: child_static
     }}
  end

  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:scheduled_static, state) do
    inst = state.inst

    if inst.enabled do
      diff_period = inst.meta.run_period || @default_refresh_seconds
      last_run = inst.meta.last_run

      case last_run do
        nil ->
          RoomGtfs.Worker.update_static_data(state.id)

        val ->
          case DateTime.diff(DateTime.utc_now(), val) do
            diff when diff > diff_period ->
              RoomGtfs.Worker.update_static_data(state.id)

            _otherwise ->
              :ok
          end
      end
    end

    {:noreply, state}
  end

  def handle_cast(:update_static, state) do
    GenServer.cast(state.child_static, :update_static)
    {:noreply, state}
  end

  def handle_cast(:update_realtime, state) do
    GenServer.cast(state.child_rt, :update_realtime)
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call({:query_realtime, trips, stop}, _from, state) do
    r =
      try do
        GenServer.call(state.child_rt, {:query_realtime, trips, stop})
      catch
        :exit, _ ->
          Logger.warning("gtfs-rt query timed out for source #{state.id}")
          []
      end

    {:reply, r, state}
  end

  def handle_call({:query_vehicle_positions, trips}, _from, state) do
    r =
      try do
        GenServer.call(state.child_rt, {:query_vehicle_positions, trips})
      catch
        :exit, _ ->
          Logger.warning("gtfs-rt vehicle positions query timed out for source #{state.id}")
          []
      end

    {:reply, r, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def source_stats(id) do
    %{
      calendars:  Storage.count_calendars(id),
      directions: Storage.count_directions(id),
      routes:     Storage.count_routes(id),
      shapes:     Storage.count_shapes(id),
      stops:      Storage.count_stops(id),
      stop_times: Storage.count_stop_times(id),
      trips:      Storage.count_trips(id),
      rt:         RoomGtfs.Worker.RT.stats(id),
    }
  end
end

defmodule RoomGtfs.Worker.RT do
  use GenServer
  @registry :zeus

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo
  alias RoomGtfs.FeedCache

  # Static stops only change when a feed is reimported.
  @stops_ttl :timer.minutes(5)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs-rt" <> opts[:name]))
  end

  def update_realtime_data(name) do
    "gtfs-rt#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_realtime)
  end

  def refresh_db_cfg(name) do
    "gtfs-rt#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def stats(name) do
    try do
      "gtfs-rt#{name}"
      |> via_tuple()
      |> GenServer.call(:stats)
    catch
      :exit, _ -> %{rt_sa: :unavailable, rt_tu: :unavailable, rt_vp: :unavailable}
    end
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(4),
      run: fn -> RoomGtfs.Worker.RT.refresh_db_cfg(opts[:name]) end,
      initial_delay: :timer.seconds(10)
    )

    Periodic.start_link(
      every: :timer.seconds(30),
      run: fn -> RoomGtfs.Worker.RT.update_realtime_data(opts[:name]) end,
      initial_delay: :timer.seconds(60)
    )

    {:ok,
     %{
       id: opts[:name],
       inst: nil,
       rt_sa: nil,
       rt_tu: nil,
       rt_vp: nil,
       # stop_id => {lat, lon}, for feeds that report a station instead of a
       # coordinate. See vehicle_positions_from/2.
       stops: %{},
       stops_at: nil
     }}
  end

  defp bcast(id, :disabled) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, :disabled})
  end

  # Every realtime fetch goes through here so that the outcome is recorded
  # whether it worked or not. The logs already say when one fails; what they
  # cannot say is that a feed stopped being fetched at all, which is the failure
  # that looks exactly like silence. See RoomGtfs.FeedHealth.
  defp fetch_recorded(state, kind, url) do
    started = System.monotonic_time(:millisecond)

    # A source polling every three minutes can happily use data up to three
    # minutes old, and several sources sharing one URL -- which is the whole
    # point of the regional feed -- then fetch it once between them instead of
    # once each.
    result =
      case rt_period_ms(state) do
        nil -> FeedCache.get(url)
        period -> FeedCache.get(url, period - :timer.seconds(5))
      end
    took = System.monotonic_time(:millisecond) - started

    RoomGtfs.FeedHealth.record(state.id, state.inst && state.inst.name, kind, url, result, took)

    result
  end

  @doc """
  Narrow a multi-agency feed to one source, and unprefix what is left.

  511's regional feed carries 28 operators in one message, which is how three
  Bay Area sources share a single request against a 60-per-hour quota. Trips
  there are keyed `SF:12074394_M21`, and the static feed calls the same trip
  `12074394_M21`, so a source reading the regional feed matches nothing until
  the prefix comes off.

  Stripping alone would be wrong. Two operators can use the same trip id --
  short numeric ids like "1100" are common -- so entities belonging to other
  agencies are dropped rather than unprefixed into a namespace where they can
  collide. Only stop ids are left alone, because the regional feed does not
  prefix those.

  A source with no `rt_agency` gets its feed back untouched, which is every
  single-agency feed.
  """
  def for_this_agency(feed, %{inst: %{config: %{rt_agency: agency}}})
      when is_binary(agency) and agency != "" do
    prefix = agency <> ":"

    entities =
      feed.entity
      |> Enum.filter(&belongs_to?(&1, prefix))
      |> Enum.map(&unprefix(&1, prefix))

    %{feed | entity: entities}
  end

  def for_this_agency(feed, _state), do: feed

  defp belongs_to?(entity, prefix) do
    String.starts_with?(entity_trip_id(entity) || "", prefix)
  end

  defp entity_trip_id(%{trip_update: %{trip: %{trip_id: id}}}) when is_binary(id), do: id
  defp entity_trip_id(%{vehicle: %{trip: %{trip_id: id}}}) when is_binary(id), do: id
  defp entity_trip_id(_entity), do: nil

  defp unprefix(entity, prefix) do
    entity
    |> update_trip(entity.trip_update, prefix, :trip_update)
    |> then(fn e -> update_trip(e, e.vehicle, prefix, :vehicle) end)
  end

  defp update_trip(entity, nil, _prefix, _key), do: entity

  defp update_trip(entity, %{trip: nil}, _prefix, _key), do: entity

  defp update_trip(entity, %{trip: trip} = message, prefix, key) do
    trip = %{trip | trip_id: String.replace_prefix(trip.trip_id || "", prefix, "")}
    Map.put(entity, key, %{message | trip: trip})
  end

  defp update_trip(entity, _message, _prefix, _key), do: entity

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def handle_call({:query_alerts, stop, route_ids}, _from, state) do
    now = System.os_time(:second)

    alerts = case state.rt_sa do
      nil -> []
      feed ->
        feed.entity
        |> Enum.filter(& &1.alert)
        |> Enum.map(& &1.alert)
        |> Enum.filter(fn alert ->
          active = case alert.active_period do
            [] -> true
            periods -> Enum.any?(periods, fn p ->
              (p.start == nil || p.start <= now) &&
              (Map.get(p, :end) == nil || Map.get(p, :end) >= now)
            end)
          end
          relevant = Enum.any?(alert.informed_entity, fn e ->
            (e.stop_id != nil && e.stop_id == stop) ||
            (e.route_id != nil && e.route_id in route_ids) ||
            (e.agency_id != nil && e.stop_id == nil && e.route_id == nil) ||
            (e.stop_id == nil && e.route_id == nil && e.trip == nil && e.agency_id == nil)
          end)
          active && relevant
        end)
        |> Enum.map(fn alert ->
          route_id = Enum.find_value(alert.informed_entity, fn e -> e.route_id end)
          %{
            effect:      alert.effect |> to_string(),
            cause:       alert.cause |> to_string(),
            header:      get_translation(alert.header_text),
            description: get_translation(alert.description_text),
            route_id:    route_id,
          }
        end)
    end

    {:reply, alerts, state}
  end

  def handle_call(:current_alerts, _from, state) do
    now = System.os_time(:second)

    alerts =
      case state.rt_sa do
        nil ->
          []

        feed ->
          feed.entity
          |> Enum.filter(& &1.alert)
          |> Enum.filter(fn entity -> alert_active?(entity.alert, now) end)
          |> Enum.map(&present_alert/1)
      end

    {:reply, alerts, state}
  end

  defp alert_active?(alert, now) do
    case alert.active_period do
      [] ->
        true

      periods ->
        Enum.any?(periods, fn p ->
          (p.start == nil or p.start <= now) and
            (Map.get(p, :end) == nil or Map.get(p, :end) >= now)
        end)
    end
  end

  # An alert names what it affects as a list of informed entities, each of
  # which may carry a route, a stop, both, or neither -- "neither" meaning the
  # whole agency. Those ids are the thing worth reading: they say whether an
  # alert touches anything you would want a query for.
  defp present_alert(entity) do
    alert = entity.alert

    %{
      id: entity.id,
      effect: alert.effect |> to_string(),
      cause: alert.cause |> to_string(),
      header: get_translation(alert.header_text),
      description: get_translation(alert.description_text),
      url: get_translation(alert.url),
      route_ids: informed(alert, :route_id),
      stop_ids: informed(alert, :stop_id),
      agency_wide?: Enum.any?(alert.informed_entity, fn e ->
        e.route_id in [nil, ""] and e.stop_id in [nil, ""] and e.trip == nil
      end),
      starts_at: alert.active_period |> Enum.map(& &1.start) |> Enum.reject(&is_nil/1) |> Enum.min(fn -> nil end),
      ends_at: alert.active_period |> Enum.map(&Map.get(&1, :end)) |> Enum.reject(&is_nil/1) |> Enum.max(fn -> nil end)
    }
  end

  defp informed(alert, key) do
    alert.informed_entity
    |> Enum.map(&Map.get(&1, key))
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp get_translation(nil), do: nil
  defp get_translation(%{translation: []}), do: nil
  defp get_translation(%{translation: translations}) do
    t = Enum.find(translations, fn t -> t.language in ["en", "en-US", nil] end) || List.first(translations)
    t && t.text
  end

  def handle_call(:stats, _from, state) do
    {:reply, %{
      rt_sa: feed_summary(state.rt_sa),
      rt_tu: feed_summary(state.rt_tu),
      rt_vp: feed_summary(state.rt_vp),
    }, state}
  end

  defp feed_summary(nil), do: %{loaded: false}
  defp feed_summary(feed) when is_struct(feed, TransitRealtime.FeedMessage) do
    %{
      loaded:           true,
      header_timestamp: feed.header.timestamp,
      entity_count:     length(feed.entity),
      trip_updates:     Enum.count(feed.entity, & &1.trip_update),
      vehicle_positions: Enum.count(feed.entity, & &1.vehicle),
      alerts:           Enum.count(feed.entity, & &1.alert),
    }
  end
  defp feed_summary(_), do: %{loaded: false}

  # Helper function to extract vehicle positions from protobuf data
  @doc """
  Vehicles from a realtime feed, placed on the map.

  A GTFS-RT VehiclePosition may carry a `position` and may not. Buses do:
  every one of the MTA's 318 had a latitude. NYCT subway trains do not -- not
  one of 45 did -- because what the subway reports is which station a train is
  at or heading to, `stop_id` plus `current_status`, and never a coordinate.
  Filtering on `position` therefore drew every bus and no train at all.

  So a train without a position is placed at the stop it names, and marked
  `position_inferred: true` so nothing downstream mistakes it for a fix. For a
  subway that is arguably the more useful reading anyway: you care which
  station it is at, not where it is in the tunnel.

  `stops` is a `stop_id => {lat, lon}` map from the source's own static feed.
  Empty, this behaves as it always did.
  """
  def vehicle_positions_from(nil, _stops), do: []

  def vehicle_positions_from(%{entity: entities}, stops) do
    entities
    |> Enum.filter(& &1.vehicle)
    |> Enum.flat_map(fn entity -> [place_vehicle(entity.vehicle, stops)] end)
    |> Enum.reject(&is_nil/1)
  end

  def vehicle_positions_from(_feed, _stops), do: []

  defp place_vehicle(v, stops) do
    base = %{
      vehicle_id: v.vehicle && v.vehicle.id,
      trip_id: v.trip && v.trip.trip_id,
      route_id: v.trip && v.trip.route_id,
      stop_id: v.stop_id,
      current_status: v.current_status,
      timestamp: v.timestamp
    }

    case {v.position, v.stop_id && Map.get(stops, v.stop_id)} do
      {%{latitude: lat, longitude: lon} = pos, _} when not is_nil(lat) and not is_nil(lon) ->
        Map.merge(base, %{
          latitude: lat,
          longitude: lon,
          bearing: pos.bearing,
          position_inferred: false
        })

      {_, {lat, lon}} when not is_nil(lat) and not is_nil(lon) ->
        # No bearing: the stop knows where it is, not which way the train faces.
        Map.merge(base, %{
          latitude: lat,
          longitude: lon,
          bearing: nil,
          position_inferred: true
        })

      _ ->
        nil
    end
  end

  # Static stops for this source, as the fallback above needs them. Reloaded at
  # most every few minutes: they only change when a feed is reimported, and a
  # subway feed is 1,488 rows that would otherwise be read on every poll.
  defp ensure_stops(state) do
    now = System.monotonic_time(:millisecond)

    # Matched rather than defaulted: the key is present from init with a value of
    # nil, so Map.get/3's default never fired and the first poll of every worker
    # arithmetic'd against nil.
    stale? =
      case state.stops_at do
        nil -> true
        at -> now - at >= @stops_ttl
      end

    if stale? do
      stops =
        state.id
        |> Storage.list_stops()
        |> Map.new(fn stop -> {stop.stop_id, {stop.stop_lat, stop.stop_lon}} end)

      state |> Map.put(:stops, stops) |> Map.put(:stops_at, now)
    else
      state
    end
  end


  def fetch_rt_url(url) do
    case HTTPoison.get(url, [], follow_redirect: true) do
      {:ok, %{status_code: 200} = result} ->
        decode_rt(url, result)

      {:ok, result} ->
        Logger.warning(
          "gtfs-rt url #{url} answered HTTP #{result.status_code}: #{body_hint(result.body)}"
        )

        {:error, :bad_status}

      {:error, error} ->
        {:error, error}
    end
  end

  # A dead endpoint rarely says so with a status code. MBTA's CDN answers a
  # missing object with 200 and an S3 AccessDenied document, which the decoder
  # then reads as protobuf and reports as "closing group 7 but no groups are
  # open" -- true, and useless for working out that the URL is wrong.
  defp decode_rt(url, %{body: body} = result) do
    if protobuf_response?(result) do
      try do
        {:ok, TransitRealtime.FeedMessage.decode(body)}
      rescue
        e ->
          Logger.warning("failed to decode gtfs-rt protobuf from #{url}: #{inspect(e)}")
          {:error, :decode_failed}
      end
    else
      Logger.warning("gtfs-rt url #{url} did not return protobuf: #{body_hint(body)}")
      {:error, :not_protobuf}
    end
  end

  # The point of this is to catch a dead endpoint answering HTTP 200 with an
  # error document, not to police content types -- publishers get those wrong.
  # The MTA's subway feeds are served as `application/json` and are protobuf, so
  # a stated type cannot be the gate: believing it there loses every subway
  # feed, and only the body knows.
  #
  # Order matters. A publisher that says protobuf is believed even if the first
  # bytes resemble markup. Failing that, a body framed as a FeedMessage is
  # accepted whatever the header claims. Only then is an obvious error document
  # rejected, and anything else still gets the benefit of the doubt -- the
  # decoder is the real arbiter and reports a body hint when it fails.
  def protobuf_response?(%{body: body} = result) do
    cond do
      declared_protobuf?(result) -> true
      feed_message_framed?(body) -> true
      markup?(body) -> false
      json_text?(body) -> false
      true -> true
    end
  end

  defp declared_protobuf?(result) do
    case content_type(result) do
      nil -> false
      type -> String.contains?(type, "protobuf") or String.contains?(type, "octet-stream")
    end
  end

  # A FeedMessage begins with its required `header` field -- tag 1, wire type 2,
  # the byte 0x0A -- then that submessage's length, and the header in turn
  # begins with its own required `gtfs_realtime_version`, tag 1 wire type 2.
  #
  # One byte is not enough to check: 0x0A is also a newline, so a JSON error
  # document that happens to start with one would pass. Two levels plus a length
  # the body can actually satisfy tells them apart.
  defp feed_message_framed?(<<0x0A, len, rest::binary>>) when len < 128 do
    byte_size(rest) >= len and match?(<<0x0A, _::binary>>, rest)
  end

  defp feed_message_framed?(_body), do: false

  # Byte-wise rather than via String: a protobuf body is frequently not valid
  # UTF-8, and only the first non-blank character is being asked about.
  defp json_text?(body) when is_binary(body) do
    case skip_blanks(body) do
      <<?{, _::binary>> -> true
      <<?[, _::binary>> -> true
      _ -> false
    end
  end

  defp json_text?(_body), do: false

  defp skip_blanks(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r, ?\n], do: skip_blanks(rest)
  defp skip_blanks(body), do: body

  defp content_type(%{headers: headers}) do
    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(name) == "content-type", do: String.downcase(value)
    end)
  end

  defp content_type(_result), do: nil

  defp markup?(body) when is_binary(body) do
    case skip_blanks(body) do
      <<?<, _::binary>> = trimmed ->
        String.starts_with?(trimmed, ["<?xml", "<!DOCTYPE", "<html", "<HTML", "<Error"])

      _ ->
        false
    end
  end

  defp markup?(_body), do: false

  # Enough of the body to recognise an error page, without pouring a 350kB
  # feed into the log.
  defp body_hint(body) when is_binary(body) do
    body |> String.slice(0, 160) |> String.replace(~r/\s+/, " ") |> String.trim()
  end

  defp body_hint(_body), do: "(no body)"

  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:update_realtime, state) do
    if rt_due?(state) do
      do_update_realtime(Map.put(state, :rt_polled_at, System.monotonic_time(:millisecond)))
    else
      {:noreply, state}
    end
  end

  # The poller ticks every 30s for everyone; a source with its own interval is
  # gated here rather than by rescheduling the Periodic, which cannot be changed
  # once started and would have to be torn down and rebuilt on every config
  # refresh.
  defp rt_due?(state) do
    case rt_period_ms(state) do
      nil ->
        true

      period ->
        case Map.get(state, :rt_polled_at) do
          nil -> true
          at -> System.monotonic_time(:millisecond) - at >= period
        end
    end
  end

  defp rt_period_ms(%{inst: %{config: %{rt_period: seconds}}}) when is_integer(seconds),
    do: :timer.seconds(seconds)

  defp rt_period_ms(_state), do: nil

  defp do_update_realtime(state) do
    state =
      case state.inst.enabled do
        true ->
          state =
            case state.inst.config |> Map.get(:url_rt_sa) do
              nil ->
                state

              val ->
                case fetch_recorded(state, :sa, val) do
                  {:ok, data_sa} when is_struct(data_sa, TransitRealtime.FeedMessage) ->
                    state |> Map.put(:rt_sa, for_this_agency(data_sa, state))

                  {:error, error} ->
                    Logger.info(
                      "failed to fetch gtfs-rt url[sa] for '#{state.inst.name}', reason: #{inspect(error)}"
                    )

                    state
                end
            end

          state =
            case state.inst.config |> Map.get(:url_rt_tu) do
              nil ->
                state

              val ->
                case fetch_recorded(state, :tu, val) do
                  {:ok, data_tu} when is_struct(data_tu, TransitRealtime.FeedMessage) ->
                    state |> Map.put(:rt_tu, for_this_agency(data_tu, state))

                  {:error, error} ->
                    Logger.info(
                      "failed to fetch gtfs-rt url[tu] for '#{state.inst.name}', reason: #{inspect(error)}"
                    )

                    state
                end
            end

          state =
            case state.inst.config |> Map.get(:url_rt_vp) do
              nil ->
                state

              val ->
                case fetch_recorded(state, :vp, val) do
                  {:ok, data_vp} when is_struct(data_vp, TransitRealtime.FeedMessage) ->
                    data_vp = for_this_agency(data_vp, state)
                    new_state = state |> Map.put(:rt_vp, data_vp) |> ensure_stops()

                    # Broadcast vehicle position updates
                    vehicles = vehicle_positions_from(data_vp, new_state.stops)
                    
                    # Broadcast to specific source channel for source page
                    Phoenix.PubSub.broadcast(
                      RoomSanctum.PubSub, 
                      "gtfs_vehicle_positions:#{state.id}", 
                      {:vehicle_positions_updated, state.id, vehicles}
                    )
                    
                    # Also broadcast to general channel for query pages
                    Phoenix.PubSub.broadcast(
                      RoomSanctum.PubSub, 
                      "gtfs_vehicle_positions", 
                      {:vehicle_positions_updated, vehicles}
                    )
                    
                    new_state

                  {:error, error} ->
                    Logger.info(
                      "failed to fetch gtfs-rt url[vp] for '#{state.inst.name}', reason: #{inspect(error)}"
                    )

                    state
                end
            end

        false ->
          bcast(state.id, :disabled)
          state
      end

    {:noreply, state}
  end

  def handle_call({:query_realtime, trips, stop}, _from, state) do
    #    IO.inspect(trips)

    # filter out the protobuf for all relevant trips and then the relevant stop on that trip, nice and small
    case state.rt_tu do
      nil ->
        {:reply, [], state}

      _otherwise ->
        relevant_trips =
          state.rt_tu.entity
          # A FeedMessage may carry any mix of entity kinds, and the MTA's subway
          # feeds put trip updates and vehicle positions in the same one -- so
          # `url_rt_tu` and `url_rt_vp` are the same URL and half of what arrives
          # here has no trip_update at all. MBTA publishes them as separate
          # files, which is why this held up until a subway source was added.
          |> Enum.filter(fn x ->
            x.trip_update && x.trip_update.trip &&
              Enum.member?(trips, x.trip_update.trip.trip_id)
          end)
          |> Enum.map(fn x ->
            x
            |> Kernel.put_in(
              [Access.key(:trip_update, %{}), Access.key(:stop_time_update, %{})],
              x.trip_update.stop_time_update
              |> Enum.filter(fn x -> x.stop_id == stop end)
              |> List.first()
            )
          end)

        {:reply, relevant_trips, state}
    end
  end

  # Both of these place vehicles through vehicle_positions_from/2, so a pull
  # here and the push broadcast on each poll agree about where a train is.
  def handle_call(:query_vehicle_positions, _from, state) do
    {:reply, vehicle_positions_from(state.rt_vp, state.stops), state}
  end

  def handle_call({:query_vehicle_positions, trips}, _from, state) do
    vehicles =
      state.rt_vp
      |> vehicle_positions_from(state.stops)
      |> Enum.filter(&(&1.trip_id && &1.trip_id in trips))

    {:reply, vehicles, state}
  end
end

defmodule RoomGtfs.Worker.Static do
  use GenServer
  require Logger
  @registry :zeus

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo
  alias RoomSanctum.Storage.GTFS

  # The files that get loaded, and the only ones file_to_atom/1 and
  # file_to_order/1 accept. Everything else in a feed -- calendar_dates.txt,
  # feed_info.txt, linked_datasets.txt -- is either handled separately or
  # ignored.
  @import_files ~w(
    agency.txt
    calendar.txt
    directions.txt
    routes.txt
    shapes.txt
    stops.txt
    stop_times.txt
    trips.txt
  )

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs-st" <> opts[:name]))
  end

  defp bcast(id, file, complete, total) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, wire_id(id), file, complete, total})
  end

  defp bcast(id, :disabled) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, wire_id(id), :disabled})
  end

  defp bcast(id, :done) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, wire_id(id), :done})
  end

  # The source page does `String.to_integer/1` on the id it receives, so these
  # messages have always carried a string — which they did by accident, because
  # the only caller was a GenServer whose name is the id as a string. The
  # importer is now handed an integer by the job that runs it, so the shape is
  # pinned here rather than left to whoever happens to call.
  defp wire_id(id) when is_binary(id), do: id
  defp wire_id(id) when is_integer(id), do: Integer.to_string(id)

  def init(opts) do

#    pgopts = RoomSanctum.Repo.config()
#    {:ok, pid} = Postgrex.start_link(pgopts)

    {:ok,
     %{
       id: opts[:name],
#       pg_pid: pid
     }}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  defp get_cols(schema) do
    schema.__schema__(:fields)
    |> Enum.map(&Atom.to_string/1)
    |> List.delete("id")
    #    |> List.delete("updated_at")
    #    |> List.delete("inserted_at")
    |> Enum.join(", ")
  end

  defp get_cols(schema, cols) do
    schema.__schema__(:fields)
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(fn f -> Enum.member?(cols, f) end)
    |> List.delete("id")
    |> Enum.join(", ")
  end

  defp as_pg(type) do
    case type do
      :id -> "bigint"
      :string -> "varchar"
      :naive_datetime -> "timestamp"
      :time -> "time"
      :integer -> "integer"
      :float -> "double precision"
      :date -> "date"
      EctoInterval -> "interval"
    end
  end

  # Feeds in the wild put whitespace-only values in optional numeric columns
  # (SFMTA's trips.txt ships ", , " for wheelchair_accessible/bikes_allowed).
  # COPY only nulls *empty* unquoted fields, so " " survives into the temp table
  # and blows up the cast with `invalid input syntax for type integer: " "`,
  # which aborts the whole file. Blank out whitespace-only values for every
  # non-text target; varchar is left alone so real values keep their spacing.
  defp cast_col(k, "varchar"), do: "#{k}::varchar"
  defp cast_col(k, type), do: "NULLIF(BTRIM(#{k}), '')::#{type}"

  def get_cols_pgtypes(schema) do
    schema.__schema__(:fields)
    |> List.delete(:id)
    |> Enum.map(fn f -> {f, schema.__schema__(:type, f) |> as_pg} end)
    |> Enum.map(fn {k,v} -> cast_col(k, v) end)
    |> Enum.join(", ")
  end

  def get_cols_pgtypes(schema, cols) do
    schema.__schema__(:fields)
    |> List.delete(:id)
    |> Enum.filter(fn f -> Enum.member?(cols |> Enum.map(&String.to_atom/1), f) end)
    |> Enum.map(fn f -> {f, schema.__schema__(:type, f) |> as_pg} end)
    |> Enum.map(fn {k,v} -> cast_col(k, v) end)
    |> Enum.join(", ")
  end

  def csv_cols_to_tmp_cols(cols) do
    cols
    |> Enum.map(fn x -> "#{x} varchar" end)
    |> Enum.join(", ")
  end

  def csv_cols_to_tmp_cols(cols, :add) do
    cols
    |> Kernel.++(["inserted_at", "updated_at", "source_id"])
    |> Enum.map(fn x -> "#{x} varchar" end)
    |> Enum.join(", ")
end

  # CSV headers are matched by name against schema fields, so any decoration on
  # the header cell silently drops that column from the import. BART quotes its
  # stops.txt header (`"stop_id","stop_code",...`), which still produces a valid
  # quoted identifier for CREATE TABLE/COPY -- so the load "succeeds" and just
  # writes rows with every field NULL. Strip quotes, surrounding whitespace, and
  # a leading BOM so the names line up with the schema.
  defp normalize_header(col) do
    col
    |> String.trim()
    |> String.trim_leading("﻿")
    |> String.trim("\"")
    |> String.trim()
  end

  # Postgres picks its newline style from the first terminator it sees. Given
  # CR CR LF -- which Caltrain's trips.txt ships -- it decides the file is
  # CR-terminated and then reads every second line as empty, failing with
  # "missing data for column". Collapsing the CR run before each LF fixes that,
  # and mapping a lone CR to LF keeps classic CR-only files loading.
  defp rewrite_newlines(binary) do
    binary
    |> String.replace(~r/\r+\n/, "\n")
    |> String.replace("\r", "\n")
  end

  # A CR run at the end of a chunk may be finished by a LF at the start of the
  # next one, so it is held back rather than converted early.
  defp hold_trailing_cr(binary) do
    case Regex.run(~r/\r+\z/, binary, return: :index) do
      [{start, len}] -> {binary_part(binary, 0, start), binary_part(binary, start, len)}
      nil -> {binary, ""}
    end
  end

  @doc false
  # Exposed only so the normaliser can be exercised directly; the importer
  # calls the private function.
  def normalize_newlines_for_test(contents), do: normalize_newlines(contents)

  defp normalize_newlines(contents) do
    Stream.transform(
      contents,
      fn -> "" end,
      fn chunk, carry ->
        {body, pending} = hold_trailing_cr(carry <> IO.iodata_to_binary(chunk))
        {[rewrite_newlines(body)], pending}
      end,
      fn carry -> {[rewrite_newlines(carry)], ""} end,
      fn _carry -> :ok end
    )
  end

  defp write_file(contents, type, id, pid) do
    datetime = NaiveDateTime.local_now()
    Logger.info("GTFS::#{id} writing #{type} (c)")

    contents = normalize_newlines(contents)

    cols_j =
      contents
      |> Stream.chunk_every(500)
      |> Stream.map(&String.split(&1 |> List.flatten() |> List.first(), "\n"))
      |> Stream.take(1)
      |> Enum.to_list()
      |> List.flatten()
      |> List.first()
      |> String.strip
      |> String.split(",")
      |> Enum.map(&normalize_header/1)

#    cols_j = ["source_id" |cols_j]
      cols_j_plus = cols_j ++ ["inserted_at", "updated_at", "source_id"]

#    contents |> Stream.take(500) |> Enum.to_list() |> IO.inspect


    # add truncation here as necessary
    case type do
      :agencies -> RoomSanctum.Storage.truncate_agency(id)
      :calendars -> RoomSanctum.Storage.truncate_calendar(id)
      :directions -> RoomSanctum.Storage.truncate_direction(id)
      :routes -> RoomSanctum.Storage.truncate_route(id)
      :stops -> RoomSanctum.Storage.truncate_stop(id)
      :stop_times -> RoomSanctum.Storage.truncate_stop_time(id)
      :trips -> RoomSanctum.Storage.truncate_trip(id)
      :shapes -> RoomSanctum.Storage.truncate_shape(id)
      _ -> :ok
    end

    # set our variables based on the type
    {table, columns, pg_cols} =
      case type do
        :agencies -> {:gtfs_agencies, [GTFS.Agency |> get_cols(cols_j_plus)], GTFS.Agency |> get_cols_pgtypes(cols_j_plus)}
        :calendars -> {:gtfs_calendars, [GTFS.Calendar |> get_cols(cols_j_plus)], GTFS.Calendar |> get_cols_pgtypes(cols_j_plus)}
        :directions -> {:gtfs_directions, [GTFS.Direction |> get_cols(cols_j_plus)], GTFS.Direction |> get_cols_pgtypes(cols_j_plus)}
        :routes -> {:gtfs_routes, [GTFS.Route |> get_cols(cols_j_plus)], GTFS.Route |> get_cols_pgtypes(cols_j_plus)}
        :stops -> {:gtfs_stops, [GTFS.Stop |> get_cols(cols_j_plus)], GTFS.Stop |> get_cols_pgtypes(cols_j_plus)}
        :stop_times -> {:gtfs_stop_times, [GTFS.StopTime |> get_cols(cols_j_plus)], GTFS.StopTime |> get_cols_pgtypes(cols_j_plus)}
        :trips -> {:gtfs_trips, [GTFS.Trip |> get_cols(cols_j_plus)], GTFS.Trip |> get_cols_pgtypes(cols_j_plus)}
        :shapes -> {:gtfs_shapes, [GTFS.Shape |> get_cols(cols_j_plus)], GTFS.Shape |> get_cols_pgtypes(cols_j_plus)}
      end

#    IO.inspect({table, columns, pg_cols})
    # `Repo.config/0` carries Ecto's `timeout: 15000`, which looks like it would
    # cap the bulk statements below. It does not: DBConnection takes the
    # *transaction's* timeout as the default for statements run inside it, and
    # the transaction is opened with `timeout: :infinity`. Verified rather than
    # assumed -- a 3s query on a connection started with `timeout: 1000` runs
    # fine inside an `:infinity` transaction, and fails inside a 1s one.
    opts = RoomSanctum.Repo.config()
    {:ok, pid} = Postgrex.start_link(opts)

    tmp_table_name = "tmp_#{type}_#{id}"

    Postgrex.transaction(
      pid,
      fn conn ->
        # temp table
        qt =
          Postgrex.prepare!(
            conn,
            "",
            "CREATE TEMPORARY TABLE #{tmp_table_name} (#{cols_j |> csv_cols_to_tmp_cols})"
          )

        Postgrex.execute(conn, qt, [])

        qt2 =
          Postgrex.prepare!(
            conn,
            "",
            "CREATE TEMPORARY TABLE #{tmp_table_name}_allcols (#{cols_j |> csv_cols_to_tmp_cols(:add)})"
          )

        Postgrex.execute(conn, qt2, [])

        # write csv
        stream =
          Postgrex.stream(
            conn,
            "COPY #{tmp_table_name}(#{cols_j |> Enum.join(",")}) FROM STDIN CSV HEADER DELIMITER ','",
            []
          )

        Enum.into(contents, stream)

        qtc =
          Postgrex.prepare!(
            conn,
            "",
            "INSERT INTO #{tmp_table_name}_allcols (#{cols_j |> Enum.join(",")}) SELECT * FROM #{tmp_table_name}"
          )

        Postgrex.execute(conn, qtc, [])

        # update fields
        qtu =
          Postgrex.prepare!(
            conn,
            "",
            "UPDATE #{tmp_table_name}_allcols SET inserted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP, source_id = #{id}"
          )

        Postgrex.execute(conn, qtu, [])

        # write into dest table
        qs =
          Postgrex.prepare!(
            conn,
            "",
            "INSERT INTO #{atom_to_table(type)} (#{columns}) SELECT #{pg_cols} FROM #{tmp_table_name}_allcols"
          )

        Postgrex.execute(conn, qs, [])

#        qd = Postgrex.prepare!(conn, "", "DROP TABLE #{tmp_table_name}")
#        Postgrex.execute(conn, qd, [])
      end,
      timeout: :infinity
    ) |> IO.inspect
    GenServer.stop(pid)
  end

  defp write_file(contents, type, id) do
    datetime = NaiveDateTime.local_now()
    Logger.info("GTFS::#{id} writing #{type}")

    case type do
      :routes -> RoomSanctum.Storage.truncate_route(id)
      :stops -> RoomSanctum.Storage.truncate_stop(id)
      :stop_times -> RoomSanctum.Storage.truncate_stop_time(id)
      _ -> :ok
    end

    contents
    |> Stream.filter(fn {status, data} -> status == :ok end)
    |> Stream.uniq()
    |> Stream.map(fn {status, x} ->
      relevant_data =
        x
        |> Map.put("source_id", id)
        |> Map.put("inserted_at", datetime)
        |> Map.put("updated_at", datetime)

      case type do
        :agency ->
          RoomSanctum.Storage.change_agency(%RoomSanctum.Storage.GTFS.Agency{}, relevant_data).changes

        :calendar ->
          RoomSanctum.Storage.change_calendar(%RoomSanctum.Storage.GTFS.Calendar{}, relevant_data).changes

        :directions ->
          RoomSanctum.Storage.change_direction(
            %RoomSanctum.Storage.GTFS.Direction{},
            relevant_data
          ).changes

        :routes ->
          RoomSanctum.Storage.change_route(%RoomSanctum.Storage.GTFS.Route{}, relevant_data).changes

        :stops ->
          RoomSanctum.Storage.change_stop(%RoomSanctum.Storage.GTFS.Stop{}, relevant_data).changes

        :stop_times ->
          RoomSanctum.Storage.change_stop_time(
            %RoomSanctum.Storage.GTFS.StopTime{},
            relevant_data
          ).changes

        :trips ->
          RoomSanctum.Storage.change_trip(%RoomSanctum.Storage.GTFS.Trip{}, relevant_data).changes
      end
      |> Map.put(:inserted_at, datetime)
      |> Map.put(:updated_at, datetime)
    end)
    |> Stream.chunk_every(2000)
    |> Stream.map(fn chunked_data ->
      chunked_data =
        chunked_data
        |> Enum.uniq()

      case type do
        :agency ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Agency,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :agency_id]
          )

        :calendar ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Calendar,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :service_id]
          )

        :directions ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Direction,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :route_id, :direction_id]
          )

        :routes ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Route,
            chunked_data
          )

        :stops ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Stop,
            chunked_data
          )

        :stop_times ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.StopTime,
            chunked_data
          )

        :trips ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Trip,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :trip_id]
          )
      end
    end)
    |> Enum.count()

    DateTime.utc_now()
  end


  # linked_datasets.txt associates GTFS-RT feeds with the schedule that
  # describes them, so a feed that ships one can wire up its own realtime URLs.
  #
  # Publishers disagree on the details, so this reads by header name rather
  # than position: MBTA ships five columns and writes the flags as 1/0, while
  # Caltrain ships seven and writes true/false.
  @rt_flag_fields [
    {"trip_updates", :url_rt_tu},
    {"vehicle_positions", :url_rt_vp},
    {"service_alerts", :url_rt_sa}
  ]

  def parse_linked_datasets(csv) do
    case String.split(csv, ~r/\r?\n/, trim: true) do
      [] ->
        []

      [header | rows] ->
        keys = header |> String.split(",") |> Enum.map(&normalize_header/1)

        Enum.map(rows, fn row ->
          keys
          |> Enum.zip(String.split(row, ","))
          |> Map.new(fn {k, v} -> {k, String.trim(v)} end)
        end)
    end
  end

  defp rt_flag?(value) do
    String.downcase(String.trim(value || "")) in ["1", "true", "yes"]
  end

  # A feed behind a key cannot be fetched with what we have, so it is left for
  # the user to fill in by hand rather than saved as a URL that always 401s.
  defp rt_open?(row) do
    case Map.get(row, "authentication_type") do
      nil -> true
      value -> String.downcase(String.trim(value)) in ["", "0", "none"]
    end
  end

  def linked_dataset_urls(rows) do
    Enum.reduce(@rt_flag_fields, %{}, fn {flag, field}, acc ->
      row = Enum.find(rows, fn r -> rt_flag?(Map.get(r, flag)) and rt_open?(r) end)
      url = row && String.trim(Map.get(row, "url") || "")

      if url in [nil, ""], do: acc, else: Map.put(acc, field, url)
    end)
  end

  # Only ever fills blanks: a URL already in the config was put there
  # deliberately and outranks whatever the feed advertises.
  defp apply_linked_datasets(cfg, urls) do
    {configured, blank} =
      Enum.split_with(urls, fn {field, _url} ->
        existing = Map.get(cfg.config, field)
        is_binary(existing) and String.trim(existing) != ""
      end)

    # A URL set by hand still wins -- it may be a proxy, or carry a key the
    # feed cannot know about. But when the feed names a different one it is
    # worth saying so out loud: a stale URL usually fails as a decode error
    # somewhere else entirely, with nothing pointing back here.
    for {field, url} <- configured, Map.get(cfg.config, field) != url do
      Logger.warning(
        "GTFS::#{cfg.id} #{field} is set to #{Map.get(cfg.config, field)} " <>
          "but the feed advertises #{url}"
      )
    end

    fill = Map.new(blank)

    if fill == %{} do
      :ok
    else
      Logger.info("GTFS::#{cfg.id} linked_datasets supplied #{inspect(Map.keys(fill))}")
      Configuration.update_source_config(cfg, fill)
    end
  end

  defp file_to_atom(filename) do
    case filename do
      "agency.txt" ->
        :agencies

      "calendar.txt" ->
        :calendars

      "directions.txt" ->
        :directions

      "routes.txt" ->
        :routes

      "stops.txt" ->
        :stops

      "stop_times.txt" ->
        :stop_times

      "trips.txt" ->
        :trips

      "shapes.txt" ->
        :shapes
    end
  end

  # The order the progress bar counts in, which has to be the order the files are
  # actually written in or the bar moves backwards. Entries come from the zip's
  # own directory, which for every feed seen here is alphabetical -- so shapes is
  # written fifth, between routes and stops, and was previously numbered tenth.
  # Being numbered last meant its step arrived as "10 of 10", which the source
  # page reads as completion: the bar hit 100% and flipped to idle while three
  # more files, stop_times included, were still to load.
  def file_to_order(filename) do
    case filename do
      "agency.txt" -> 3
      "calendar.txt" -> 4
      "directions.txt" -> 5
      "routes.txt" -> 6
      "shapes.txt" -> 7
      "stops.txt" -> 8
      "stop_times.txt" -> 9
      "trips.txt" -> 10
    end
  end

  defp atom_to_table(atom) do
    "gtfs_#{atom}"
  end

  @doc """
  Import a source's static feed, start to finish, in the calling process.

  This is the slow half of GTFS: download a zip, then COPY eight files into
  Postgres, of which stop_times runs to millions of rows and is preceded by a
  delete of the millions already there. It is deliberately synchronous — the
  caller is held for the whole import, which is what lets `RoomGtfs.ImportJob`
  bound how many run at once. Casting this at a GenServer instead, as the
  scheduler used to, means the cast returns immediately and nothing anywhere
  knows how many imports are in flight.

  Returns `:ok` once the feed has been written, or `{:error, reason}` for a
  failure that happened before anything was written — a download that failed, a
  body that was not a zip. Those are safe to retry. A file that fails *during*
  the load is logged and the import still finishes and stamps `last_run`, which
  is long-standing behaviour: a retry would truncate and reload the seven files
  that did work.
  """
  def import_static(id) do
    cfg = Configuration.get_source!(id)

    if cfg.enabled do
      do_import_static(id, cfg)
    else
      # Previously a `case cfg.enabled do true -> ... end`, which raised
      # CaseClauseError on a disabled source. Harmless when it was a cast into
      # a GenServer that restarted; as a queued job it would fail, retry and
      # fail again.
      Logger.info("GTFS::#{id} static import skipped, source is disabled")
      :ok
    end
  end

  # Bytes after the end-of-central-directory record, which some publishers add
  # and the zip format does not allow undeclared.
  #
  # 511.org appends an HTML fragment to every GTFS download -- 680 bytes of
  # `<!DOCTYPE html ...>` -- while declaring a comment length of zero. The
  # `unzip` command shrugs and reads the archive anyway; Unzip looks for the
  # EOCD at the tail of the blob, does not find it there, and reports "missing
  # EOCD record". A ten megabyte feed then fails to import over 680 bytes of
  # markup, and the error names neither the cause nor the culprit.
  #
  # So the record is found and anything past it dropped. A well-formed archive
  # ends exactly at its EOCD and comes back untouched.
  def trim_zip_tail(body) when is_binary(body) do
    case last_eocd_offset(body) do
      nil ->
        body

      offset ->
        <<_::binary-size(offset), _::binary-size(20), comment_len::16-little, _rest::binary>> = body
        declared_end = offset + 22 + comment_len

        if byte_size(body) > declared_end do
          Logger.info(
            "gtfs zip carried #{byte_size(body) - declared_end} bytes after its EOCD; trimming"
          )

          binary_part(body, 0, declared_end)
        else
          body
        end
    end
  end

  def trim_zip_tail(body), do: body

  # Searched from the end, and only over the tail: the signature is four bytes
  # and can occur by chance inside compressed data, so the last plausible
  # occurrence is the one that means anything. 128KB covers a legal 64KB comment
  # and then some junk on top of it.
  defp last_eocd_offset(body) do
    window = min(byte_size(body), 128 * 1024)
    start = byte_size(body) - window

    body
    |> binary_part(start, window)
    |> then(&:binary.matches(&1, <<0x50, 0x4B, 0x05, 0x06>>))
    |> Enum.map(fn {at, _len} -> start + at end)
    |> Enum.filter(&(&1 + 22 <= byte_size(body)))
    |> List.last()
  end

  defp do_import_static(id, cfg) do
    Logger.info("GTFS::#{id} updating static info")
    bcast(id, :downloading, 1, 11)

    case HTTPoison.get(cfg.config.url, [], follow_redirect: true) do
      {:ok, result} ->
        bcast(id, :extracting, 2, 11)

        case result.body |> trim_zip_tail() |> Unzip.InMem.new() |> Unzip.new() do
          {:ok, unzip} ->
            files = Unzip.list_entries(unzip)

            case Enum.find(files, &(&1.file_name == "linked_datasets.txt")) do
              nil ->
                :ok

              entry ->
                Unzip.file_stream!(unzip, entry.file_name)
                |> Enum.to_list()
                |> IO.iodata_to_binary()
                |> parse_linked_datasets()
                |> linked_dataset_urls()
                |> then(&apply_linked_datasets(cfg, &1))
            end

            try do
              # Sorted, because `Unzip.list_entries/1` maps over `cd_list`, which
              # is a map -- so the order it hands back is neither the zip's nor
              # alphabetical, it is whatever the hash gives. Left to that, the
              # progress bar walks backwards: stop_times (step 9) came out ahead
              # of stops (step 8) on the MTA feeds. Sorting by the same function
              # that numbers the steps makes the order the bar claims the order
              # the files are actually written in, for every feed.
              files
              |> Enum.filter(&(&1.file_name in @import_files))
              |> Enum.sort_by(&file_to_order(&1.file_name))
              |> Enum.map(fn e ->
                type = file_to_atom(e.file_name)

                bcast(id, type, file_to_order(e.file_name), 11)

                Unzip.file_stream!(unzip, e.file_name)
                |> write_file(type, id, nil)
              end)
            rescue
              e ->
                Logger.error("GTFS::#{id} error during static import: #{inspect(e)}")
            after
              Configuration.update_source_meta(cfg, %{last_run: DateTime.utc_now()})
              bcast(id, :done)
            end

            :ok

          {:error, term} ->
            # `Logger.error/1` takes chardata, not a struct: passing the
            # raw term raised here, inside the branch meant to report the
            # error.
            Logger.error("GTFS::#{id} static feed was not a readable zip: #{inspect(term)}")
            {:error, {:unzip, term}}
        end

      {:error, error} ->
        Logger.error("GTFS::#{id} static feed download failed: #{inspect(error)}")
        {:error, {:download, error}}
    end
  end

  defp replace(string) do
    String.replace(string, ~s("), "")
  end

  # Runs the import immediately, in this GenServer, bypassing the queue.
  # Nothing in the app reaches this any more — `update_static_data/1` enqueues
  # instead — but it is left as the way to force one feed from IEx without
  # waiting behind whatever else is queued.
  @impl true
  def handle_cast(:update_static, state) do
    import_static(state.id)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:update_static_old, state) do
    cfg = Configuration.get_source!(state.id)

    case cfg.enabled do
      true ->
        Logger.info("GTFS::#{state.id} updating static info")
        bcast(state.id, :downloading, 1, 10)

        case HTTPoison.get(cfg.config.url) do
          {:ok, result} ->
            bcast(state.id, :extracting, 2, 10)

            case result.body
                 |> :zip.unzip([:memory]) do
              {:ok, files} ->
                files
                |> Enum.map(fn {name, data} ->
                  as_csv =
                    data
                    |> String.split("\n")
                    |> Enum.map(&replace/1)
                    |> Enum.filter(fn x -> x != "" end)
                    |> XP.parse_stream

                  Logger.info({"datum", as_csv})
                  IO.inspect({"datum", as_csv})

                  case name do
                    'agency.txt' ->
                      write_file(as_csv, :agency, state.id)
                      bcast(state.id, :agency, 3, 9)

                    'calendar.txt' ->
                      write_file(as_csv, :calendar, state.id)
                      bcast(state.id, :calendar, 4, 9)

                    'directions.txt' ->
                      write_file(as_csv, :directions, state.id)
                      bcast(state.id, :directions, 5, 9)

                    'routes.txt' ->
                      write_file(as_csv, :routes, state.id)
                      bcast(state.id, :routes, 6, 9)

                    'stops.txt' ->
                      write_file(as_csv, :stops, state.id)
                      bcast(state.id, :stops, 7, 9)

                    'stop_times.txt' ->
                      write_file(data, :stop_times, state.id, via: :copy)
                      bcast(state.id, :stop_times, 8, 9)

                    'trips.txt' ->
                      write_file(as_csv, :trips, state.id)
                      bcast(state.id, :trips, 9, 9)

                    _other ->
                      :ok
                  end
                end)

                Logger.info("GTFS::#{state.id} completed import")

                Configuration.update_source_meta(cfg, %{last_run: DateTime.utc_now()})

              {:error, _info} ->
                bcast(state.id, :error, 1, 1)
                Logger.info("GTFS::#{state.id} Got invalid zip file #{_info.reason}")
            end

          {:error, info} ->
            Logger.info(info.reason)
        end

      false ->
        bcast(state.id, :disabled)
        {:noreply, state}
    end

    {:noreply, state}
  end
end

defmodule RoomGtfs.Debug do
  @moduledoc """
  IEx helpers for debugging GTFS realtime connections.

  ## Quick start

      # Show configured RT URLs for a source
      RoomGtfs.Debug.urls(1)

      # Fetch a RT URL directly and report what comes back
      RoomGtfs.Debug.fetch_url("https://example.com/gtfs-rt/trip-updates")

      # Inspect live entity counts held in the RT worker's state
      RoomGtfs.Debug.rt_state(1)

      # Run the full stop query pipeline (static + RT merge) and inspect result
      RoomGtfs.Debug.query_stop(1, %{stop: "stop_id_here"})
  """

  alias RoomSanctum.Configuration

  @doc """
  Print the configured RT URLs for the given source id.
  """
  def urls(id) do
    cfg = Configuration.get_source!(id)
    %{
      name:      cfg.name,
      url_rt_sa: cfg.config.url_rt_sa,
      url_rt_tu: cfg.config.url_rt_tu,
      url_rt_vp: cfg.config.url_rt_vp,
    } |> IO.inspect(label: "RT URLs for source #{id}")
  end

  @doc """
  Fetch a RT URL directly and report the result without touching worker state.
  Shows entity counts on success, or the error on failure.
  """
  def fetch_url(url) do
    IO.puts("Fetching #{url} ...")
    case RoomGtfs.Worker.RT.fetch_rt_url(url) do
      {:ok, feed} ->
        summary = %{
          header_timestamp: feed.header.timestamp,
          entity_count:     length(feed.entity),
          trip_updates:     feed.entity |> Enum.count(& &1.trip_update),
          vehicle_positions: feed.entity |> Enum.count(& &1.vehicle),
          alerts:           feed.entity |> Enum.count(& &1.alert),
        }
        IO.inspect(summary, label: "Feed summary")
        {:ok, feed}

      {:error, reason} ->
        IO.inspect(reason, label: "Fetch failed")
        {:error, reason}
    end
  end

  @doc """
  Fetch each configured RT URL for a source and summarise what comes back.
  """
  def fetch_all(id) do
    cfg = Configuration.get_source!(id)
    for {label, url} <- [sa: cfg.config.url_rt_sa, tu: cfg.config.url_rt_tu, vp: cfg.config.url_rt_vp],
        url != nil do
      IO.puts("\n--- #{label} ---")
      fetch_url(url)
    end
    :ok
  end

  @doc """
  Peek at the RT worker's current in-memory state for a source.
  Shows entity counts for each cached feed without triggering a new fetch.
  """
  def rt_state(id) do
    case dbg_pid(id) do
      :undefined ->
        IO.puts("RT worker for source #{id} not found — is it running?")

      pid ->
        state = :sys.get_state(pid)
        %{
          rt_sa: feed_summary(state.rt_sa),
          rt_tu: feed_summary(state.rt_tu),
          rt_vp: feed_summary(state.rt_vp),
        } |> IO.inspect(label: "RT worker state for source #{id}")
    end
  end

  @doc """
  Run the full query_stop pipeline for a source and stop, then pretty-print results.
  Shows both the static schedule and which entries got live times merged in.
  """
  def query_stop(id, query) do
    IO.puts("Running query_stop for source=#{id} stop=#{query.stop} ...")
    results = RoomGtfs.Worker.query_stop(id, query)
    IO.puts("#{length(results)} arrivals:")
    for r <- results do
      route_id = get_in(r, [:trip, :route_id]) || get_in(r, [:trip, :route, :route_id]) || "?"
      headsign = get_in(r, [:trip, :trip_headsign]) || "?"
      live = case Map.get(r, :arrival_time_live_ts) do
        nil -> ""
        ts  -> " [LIVE ts=#{ts} delay=#{r.arrival_time_live_delay}s]"
      end
      IO.puts("  route=#{route_id}  trip=#{r.trip_id}  to=#{headsign}  arrival=#{r.arrival_time}#{live}")
    end
    results
  end

  @doc """
  Dump the raw trip_update entities from the cached TU feed for a source,
  optionally filtered to a specific stop_id.
  """
  def dump_tu(id, stop_id \\ nil) do
    case dbg_pid(id) do
      :undefined ->
        IO.puts("RT worker for source #{id} not found")

      pid ->
        state = :sys.get_state(pid)
        case state.rt_tu do
          nil ->
            IO.puts("rt_tu is nil — no successful fetch yet")

          feed ->
            entities = feed.entity |> Enum.filter(& &1.trip_update)
            entities = if stop_id do
              entities |> Enum.filter(fn e ->
                Enum.any?(e.trip_update.stop_time_update, & &1.stop_id == stop_id)
              end)
            else
              entities
            end
            IO.puts("#{length(entities)} trip_update entities#{if stop_id, do: " for stop #{stop_id}", else: ""}:")
            entities |> IO.inspect(limit: :infinity)
        end
    end
  end

  @doc """
  Diagnose why live times aren't appearing for a stop.
  Compares static trip IDs against RT feed trip IDs and stop_id formats,
  and traces exactly where the merge pipeline loses data.
  """
  def diagnose(id, stop) do
    alias RoomSanctum.Storage

    IO.puts("\n=== RT state ===")
    rt_summary = case dbg_pid(id) do
      :undefined ->
        IO.puts("RT worker not found!")
        nil
      pid ->
        state = :sys.get_state(pid)
        IO.puts("rt_tu: #{inspect(feed_summary(state.rt_tu))}")
        state.rt_tu
    end

    IO.puts("\n=== Static arrivals for stop #{stop} ===")
    static = Storage.get_upcoming_arrivals_for_stop(id, stop) |> Storage.fix_arrival_times
    static_trip_ids = static |> Enum.map(& &1.trip_id)
    IO.puts("#{length(static)} static trips: #{inspect(Enum.take(static_trip_ids, 5))}#{if length(static_trip_ids) > 5, do: " ...", else: ""}")

    if rt_summary do
      IO.puts("\n=== RT feed trip IDs (sample of 5) ===")
      rt_trip_ids = rt_summary.entity
        |> Enum.filter(& &1.trip_update)
        |> Enum.map(& &1.trip_update.trip.trip_id)
      IO.puts("#{length(rt_trip_ids)} total RT trip updates")
      IO.puts("Sample: #{inspect(Enum.take(rt_trip_ids, 5))}")

      IO.puts("\n=== Trip ID overlap ===")
      matched = MapSet.intersection(MapSet.new(static_trip_ids), MapSet.new(rt_trip_ids))
      IO.puts("#{MapSet.size(matched)} of #{length(static_trip_ids)} static trips found in RT feed")
      if MapSet.size(matched) > 0 do
        IO.puts("Matched trip IDs: #{inspect(MapSet.to_list(matched))}")
      else
        IO.puts("NO OVERLAP — trip ID format mismatch likely")
        IO.puts("  Static example: #{inspect(List.first(static_trip_ids))}")
        IO.puts("  RT example:     #{inspect(List.first(rt_trip_ids))}")
      end

      IO.puts("\n=== stop_id format check ===")
      rt_stop_ids = rt_summary.entity
        |> Enum.filter(& &1.trip_update)
        |> Enum.flat_map(& &1.trip_update.stop_time_update)
        |> Enum.map(& &1.stop_id)
        |> Enum.uniq()
        |> Enum.take(5)
      IO.puts("Static stop_id: #{inspect(stop)}")
      IO.puts("RT stop_ids (sample): #{inspect(rt_stop_ids)}")
      stop_match = rt_summary.entity
        |> Enum.filter(& &1.trip_update)
        |> Enum.flat_map(& &1.trip_update.stop_time_update)
        |> Enum.any?(& &1.stop_id == stop)
      IO.puts("stop_id #{inspect(stop)} found in RT feed: #{stop_match}")
    end

    :ok
  end

  defp feed_summary(nil), do: :not_loaded
  defp feed_summary(feed) when is_struct(feed, TransitRealtime.FeedMessage) do
    %{
      header_timestamp: feed.header.timestamp,
      entity_count:     length(feed.entity),
    }
  end
  defp feed_summary(other), do: {:unexpected, other}

  defp dbg_pid(id) do
    case Registry.lookup(:zeus, "gtfs-rt#{id}") do
      [{pid, _}] -> pid
      _ -> :undefined
    end
  end
end
