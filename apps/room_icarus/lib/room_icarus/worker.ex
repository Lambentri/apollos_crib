defmodule RoomIcarus.Worker do
  @moduledoc """
  Live aircraft positions from adsb.fi's open data API.

  Queries are anchored on a Foci: the worker resolves the foci to a lat/lon and
  polls `/v3/lat/{lat}/lon/{lon}/dist/{dist}`, which returns every aircraft the
  network can see within `dist` nautical miles, already annotated with `dst`
  (distance) and `dir` (bearing) relative to that point.

  adsb.fi caps public endpoints at 1 request/second and temporarily blocks IPs
  that trip 4xx/429, so refreshes are spaced by `@request_spacing_ms` and only
  cover targets a query has actually asked for.

  Positions are stale within seconds, so nothing is persisted -- the worker holds
  the latest snapshot per target in memory, the same shape RoomPollen.Worker uses.
  """
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @endpoint "https://opendata.adsb.fi/api/v3"

  # adsb.fi refreshes its own aggregate roughly twice a minute; polling harder
  # just burns rate limit for data that has not changed.
  @refresh_seconds 15
  @request_spacing_ms 1_100

  @flight_poll_seconds 20

  @max_dist_nm 250
  @default_dist_nm 25

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("icarus#{opts[:name]}"))
  end

  def init(opts) do
    Periodic.start_link(
      # A backstop rather than a poll: source config changes are rare, and the
      # workers that read them on a tight timer were the load that kept a
      # ten-connection pool saturated. Nothing here needs to notice an edit
      # within ten seconds.
      every: :timer.seconds(60),
      run: fn -> RoomIcarus.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(@refresh_seconds),
      run: fn -> RoomIcarus.Worker.refresh_aircraft(opts[:name]) end,
      initial_delay: :timer.seconds(5)
    )

    # Flight watches have to advance even when nobody has the page open --
    # otherwise a landing is only noticed the next time someone looks, and Keryx
    # can never fire an arrival notification.
    Periodic.start_link(
      every: :timer.seconds(@flight_poll_seconds),
      run: fn -> RoomIcarus.Worker.sweep_watches(opts[:name]) end,
      initial_delay: :timer.seconds(10)
    )

    {:ok,
     %{
       id: opts[:name],
       inst: %{},
       targets: MapSet.new(),
       aircraft: %{}
     }}
  end

  def pid(name) do
    "icarus#{name}"
    |> via_tuple()
    |> GenServer.whereis()
  end

  # Public API
  def refresh_db_cfg(name), do: GenServer.cast(via("icarus#{name}"), :refresh_db_cfg)
  def refresh_aircraft(name), do: GenServer.cast(via("icarus#{name}"), :refresh_aircraft)
  def read(name, query), do: GenServer.call(via("icarus#{name}"), {:read, query})

  @doc """
  Every aircraft the worker is currently holding, across all watched areas.

  This is the whole picture rather than one query's slice, which is what a map
  of the source wants; per-query filtering stays in read/2.
  """
  def current_aircraft(name), do: GenServer.call(via("icarus#{name}"), :current_aircraft)
  def sweep_watches(name), do: GenServer.cast(via("icarus#{name}"), :sweep_watches)

  # Cast handlers
  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:refresh_aircraft, %{inst: %{enabled: true}} = state) do
    Logger.info("Icarus::#{state.id} refreshing #{MapSet.size(state.targets)} targets")

    aircraft =
      state.targets
      |> Enum.reduce(state.aircraft, fn {lat, lon, dist} = target, acc ->
        result = fetch_aircraft(lat, lon, dist)
        Process.sleep(@request_spacing_ms)

        case result do
          {:ok, list} -> Map.put(acc, target, list)
          :error -> acc
        end
      end)

    {:noreply, state |> Map.put(:aircraft, aircraft)}
  end

  def handle_cast(:refresh_aircraft, state), do: {:noreply, state}

  def handle_cast(:sweep_watches, %{inst: %{enabled: true}} = state) do
    watches = RoomSanctum.Icarus.active_watches()

    if watches != [] do
      Logger.info("Icarus::#{state.id} sweeping #{length(watches)} flight watches")
      Enum.each(watches, fn watch ->
        maybe_poll(watch)
        Process.sleep(@request_spacing_ms)
      end)
    end

    {:noreply, state}
  end

  def handle_cast(:sweep_watches, state), do: {:noreply, state}

  def handle_cast({:add_target, target}, state) do
    {:noreply, state |> Map.put(:targets, MapSet.put(state.targets, target))}
  end

  # Call handlers
  def handle_call({:read, query}, _from, state) do
    case mode_of(query) do
      :flight -> {:reply, read_flight(query), state}
      _ -> {:reply, read_area(query, state), state}
    end
  end

  def handle_call(:current_aircraft, _from, state) do
    aircraft =
      state.aircraft
      |> Map.values()
      |> List.flatten()
      |> Enum.filter(&(&1["lat"] && &1["lon"]))
      # Overlapping areas hold the same airframe twice.
      |> Enum.uniq_by(& &1["hex"])

    {:reply, aircraft, state}
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  defp mode_of(query) do
    case field(query, :mode) do
      :flight -> :flight
      "flight" -> :flight
      _ -> :area
    end
  end

  # A flight watch is durable, so the read goes through the database rather than
  # worker state -- that is what lets it survive a restart mid-flight.
  defp read_flight(query) do
    callsign = RoomIcarus.Airlines.callsign(field(query, :flight_number))
    dest = field(query, :dest)
    tz = RoomIcarus.Airports.timezone(dest)
    sched = field(query, :sched_arrival) |> to_utc(tz)

    if is_nil(callsign) or is_nil(dest) or is_nil(sched) do
      []
    else
      case RoomSanctum.Icarus.ensure_watch(callsign, dest, sched) do
        {:ok, watch} -> [watch |> maybe_poll() |> present(query, tz)]
        {:error, _} -> []
      end
    end
  end

  # Polling on read keeps the preview live, but a shared watch can be read by
  # several viewers at once and adsb.fi allows 1 request/second, so a watch is
  # only actually polled every @flight_poll_seconds.
  defp maybe_poll(watch) do
    now = DateTime.utc_now()
    due? =
      is_nil(watch.last_polled_at) or
        DateTime.diff(now, watch.last_polled_at, :second) >= @flight_poll_seconds

    if due? do
      attrs = RoomIcarus.Flight.poll(watch, now) |> Map.put(:last_polled_at, now)

      case RoomSanctum.Icarus.update_watch(watch, attrs) do
        {:ok, updated} -> updated
        {:error, _} -> watch
      end
    else
      watch
    end
  end

  # Flatten the watch into the shape the preview renders, with the delay maths
  # already done.
  defp present(watch, query, tz) do
    delay = RoomIcarus.Flight.delay_minutes(watch)
    curb = field(query, :curb_minutes) || 20

    %{
      "kind" => "flight",
      "tz" => tz,
      "callsign" => watch.callsign,
      "flight_number" => field(query, :flight_number),
      "dest" => watch.dest,
      "state" => watch.state,
      "hex" => watch.hex,
      "registration" => watch.registration,
      "aircraft_type" => watch.aircraft_type,
      "sched_arrival" => watch.sched_arrival,
      "eta" => watch.eta,
      "delay_minutes" => delay,
      "status" => status_label(watch, delay),
      "landed_at" => watch.landed_at,
      "last_seen_at" => watch.last_seen_at,
      "curb_eta" => curb_eta(watch, curb),
      "curb_minutes" => curb,
      "position" => watch.last_position
    }
  end

  defp status_label(%{state: "landed"}, _), do: "landed"
  defp status_label(%{state: "expired"}, _), do: "no sighting"
  defp status_label(%{state: "pending"}, _), do: "not airborne"
  defp status_label(_, nil), do: "tracking"
  defp status_label(_, delay) when delay <= -5, do: "early"
  defp status_label(_, delay) when delay >= 15, do: "delayed"
  defp status_label(_, _), do: "on time"

  # Wheels down is not curbside: taxi, deplaning and bags come after.
  defp curb_eta(%{state: "landed", landed_at: at}, curb) when not is_nil(at),
    do: DateTime.add(at, curb * 60)

  defp curb_eta(%{eta: eta}, curb) when not is_nil(eta), do: DateTime.add(eta, curb * 60)
  defp curb_eta(_, _), do: nil

  # The scheduled time is wall clock at the destination, so it only becomes an
  # instant once the airport's zone is applied. Without a zone we cannot know
  # what instant the user meant, so refuse rather than guess UTC.
  defp to_utc(_value, nil), do: nil

  defp to_utc(%NaiveDateTime{} = naive, tz) do
    case DateTime.from_naive(naive, tz, Tzdata.TimeZoneDatabase) do
      {:ok, dt} -> as_utc(dt)
      # Spring-forward gaps and fall-back overlaps: pick one deterministically
      # rather than dropping the watch on the two days a year it matters.
      {:ambiguous, first, _second} -> as_utc(first)
      {:gap, _just_before, just_after} -> as_utc(just_after)
      _ -> nil
    end
  end

  # from_naive/3 hands back a DateTime *in that zone*, but the watch column is
  # :utc_datetime and everything downstream compares against UTC instants, so
  # shift rather than just truncate.
  defp as_utc(%DateTime{} = dt) do
    dt |> DateTime.shift_zone!("Etc/UTC", Tzdata.TimeZoneDatabase) |> DateTime.truncate(:second)
  end

  defp to_utc(value, tz) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> to_utc(naive, tz)
      _ -> nil
    end
  end

  defp to_utc(%DateTime{} = dt, _tz), do: as_utc(dt)
  defp to_utc(_, _), do: nil

  defp read_area(query, state) do
    result =
      case target_from_query(query) do
        nil ->
          []

        {lat, lon, dist} = target ->
          GenServer.cast(self(), {:add_target, target})

          cached =
            case Map.get(state.aircraft, target) do
              # First read for this foci -- fetch inline so the preview is not
              # blank until the next periodic tick.
              nil ->
                case fetch_aircraft(lat, lon, dist) do
                  {:ok, list} -> list
                  :error -> []
                end

              list ->
                list
            end

          shape_area(cached, query)
      end

    result
  end

  # Helpers
  defp via(name), do: via_tuple(name)
  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  defp target_from_query(query) do
    case resolve_foci(RoomSanctum.Configuration.place_for!(query) || field(query, :foci_id)) do
      {lat, lon} -> {lat, lon, clamp_dist(field(query, :dist))}
      nil -> nil
    end
  end

  defp resolve_foci(nil), do: nil

  # A Plani asks from wherever its client is, which is not a foci and has no
  # row to look up.
  # Matched by shape rather than as a %Geo.Point{}: this app does not
  # depend on geo, and the only thing here with coordinates is a place.
  defp resolve_foci(%{coordinates: {lon, lat}}), do: {lat, lon}

  defp resolve_foci(foci_id) do
    try do
      case Configuration.get_foci!(foci_id) do
        %{place: %{coordinates: {lon, lat}}} -> {lat, lon}
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp field(query, key) do
    Map.get(query, key) || Map.get(query, Atom.to_string(key))
  end

  defp clamp_dist(nil), do: @default_dist_nm

  defp clamp_dist(dist) when is_integer(dist),
    do: dist |> max(1) |> min(@max_dist_nm)

  defp clamp_dist(dist) when is_binary(dist) do
    case Integer.parse(dist) do
      {n, _} -> clamp_dist(n)
      :error -> @default_dist_nm
    end
  end

  defp clamp_dist(_), do: @default_dist_nm

  # alt_baro is the string "ground" for aircraft on the surface, so a numeric
  # floor deliberately drops them while a query with no floor keeps them.
  defp filter_altitude(list, query) do
    min_alt = numeric(field(query, :alt_min))
    max_alt = numeric(field(query, :alt_max))

    cond do
      is_nil(min_alt) and is_nil(max_alt) ->
        list

      true ->
        Enum.filter(list, fn ac ->
          case ac["alt_baro"] do
            alt when is_number(alt) -> above?(alt, min_alt) and below?(alt, max_alt)
            _ -> is_nil(min_alt)
          end
        end)
    end
  end

  @doc """
  Applies an area query's filters to a cached aircraft list.

  Altitude and class first, then nearest-first, then the count cap -- so a
  limit keeps the closest aircraft the query actually asked for, rather than
  trimming the feed before it has been filtered.

  Public so the shaping can be exercised without a running worker or a foci to
  resolve.
  """
  def shape_area(list, query) do
    list
    |> filter_altitude(query)
    |> RoomIcarus.Classify.filter(field(query, :classes))
    |> Enum.sort_by(&(&1["dst"] || 0))
    |> take_limit(field(query, :limit))
  end

  # A blank or unparseable limit means no cap.
  defp take_limit(list, limit) do
    case numeric(limit) do
      n when is_number(n) and n >= 1 -> Enum.take(list, trunc(n))
      _ -> list
    end
  end

  defp above?(_alt, nil), do: true
  defp above?(alt, min_alt), do: alt >= min_alt

  defp below?(_alt, nil), do: true
  defp below?(alt, max_alt), do: alt <= max_alt

  defp numeric(nil), do: nil
  defp numeric(n) when is_number(n), do: n

  defp numeric(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp numeric(_), do: nil

  defp fetch_aircraft(lat, lon, dist) do
    url = "#{@endpoint}/lat/#{lat}/lon/#{lon}/dist/#{dist}"

    case HTTPoison.get(url, [{"Accept", "application/json"}], recv_timeout: 15_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, %{"ac" => ac}} when is_list(ac) ->
            {:ok, Enum.map(ac, &normalize_aircraft/1)}

          {:ok, _} ->
            Logger.warning("Icarus unexpected response shape")
            :error

          {:error, _} ->
            Logger.warning("Icarus JSON decode failed")
            :error
        end

      {:ok, %{status_code: 429}} ->
        Logger.warning("Icarus rate limited (429) -- backing off until next refresh")
        :error

      {:ok, %{status_code: code, body: body}} ->
        Logger.warning("Icarus HTTP #{code}: #{String.slice(body, 0, 200)}")
        :error

      {:error, err} ->
        Logger.warning("Icarus HTTP error: #{inspect(err.reason)}")
        :error
    end
  end

  # Trim the API's padded callsigns and collapse the two vertical-rate sources
  # into one field so the display does not have to know which was reported.
  # Public because RoomIcarus.Flight decodes the same aircraft shape.
  def normalize_aircraft(ac) do
    %{
      "hex" => ac["hex"],
      "flight" => ac["flight"] |> nilable_trim(),
      "registration" => ac["r"] |> nilable_trim(),
      "type" => ac["t"] |> nilable_trim(),
      "desc" => ac["desc"],
      "operator" => ac["ownOp"],
      "year" => ac["year"],
      "alt_baro" => ac["alt_baro"],
      "alt_geom" => ac["alt_geom"],
      "gs" => ac["gs"],
      "track" => ac["track"] || ac["true_heading"] || ac["mag_heading"],
      "vert_rate" => ac["baro_rate"] || ac["geom_rate"],
      "squawk" => ac["squawk"],
      "emergency" => ac["emergency"],
      "category" => ac["category"],
      "lat" => ac["lat"],
      "lon" => ac["lon"],
      "dst" => ac["dst"],
      "dir" => ac["dir"],
      "seen" => ac["seen"],
      "seen_pos" => ac["seen_pos"],
      "military" => military?(ac["dbFlags"])
    }
    |> put_class()
  end

  defp put_class(aircraft) do
    Map.put(aircraft, "class", RoomIcarus.Classify.classify(aircraft))
  end

  defp nilable_trim(nil), do: nil

  defp nilable_trim(s) when is_binary(s) do
    case String.trim(s) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp nilable_trim(other), do: other

  # readsb packs its database flags as a bitfield; bit 0 marks military.
  defp military?(flags) when is_integer(flags), do: Bitwise.band(flags, 1) == 1
  defp military?(_), do: false
end
