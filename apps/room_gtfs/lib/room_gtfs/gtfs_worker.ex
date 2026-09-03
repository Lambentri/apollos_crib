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

  @doc """
  The realtime trip updates for a stop, read rather than asked for.

  This used to be a `GenServer.call` into the source's RT worker -- the same
  process that fetches the feeds over HTTP -- so it queued behind those fetches
  and behind every other caller. A stop lookup could take tens of seconds, and
  the vision that asked for it gives up at thirty.

  The table is written on each poll and read here directly. The call remains
  for the window before a source has stored its first feed.
  """
  def get_current_realtime(name, trips, stop, config \\ nil) do
    # The caller usually holds the source already. Reading it again here would
    # put back one of the queries that taking the timezone as an argument
    # removed.
    config = config || source_config(name)

    indexed =
      case config do
        %{rt_trip_id_suffix: true} -> RoomGtfs.RTIndex.trip_updates_by_suffix(name, trips, stop)
        _otherwise -> RoomGtfs.RTIndex.trip_updates(name, trips, stop)
      end

    case indexed do
      {:ok, updates} ->
        updates

      :miss ->
        try do
          "gtfs-rt#{name}"
          |> via_tuple()
          |> GenServer.call({:query_realtime, trips, stop}, 5_000)
          |> Enum.map(&slim_entity/1)
        rescue
          # As above: a stopped Registry raises rather than exiting.
          ArgumentError -> []
        catch
          :exit, _ -> []
        end
    end
  end

  # The worker still replies with protobuf entities; the index speaks a smaller
  # shape, and callers should only have to know one of them.
  defp slim_entity(%{trip_update: tu}) do
    stu = tu.stop_time_update

    %{
      trip_id: tu.trip.trip_id,
      schedule_relationship: tu.trip.schedule_relationship,
      timestamp: tu.timestamp,
      stops: %{},
      stop:
        stu &&
          %{
            arrival: stu.arrival,
            departure: stu.departure,
            schedule_relationship: stu.schedule_relationship,
            stop_time_properties: stu.stop_time_properties,
            departure_occupancy_status: stu.departure_occupancy_status
          }
    }
  end

  # The suffix rule is a property of the source, and reading it here keeps the
  # lookup out of the worker entirely.
  defp source_config(name) do
    case Configuration.get_source!(:bare, name) do
      %{config: config} -> config
      _otherwise -> %{}
    end
  rescue
    _ -> %{}
  end

  @area_arrivals_per_stop 8
  @area_arrivals_total 16

  def query_alerts(name, stop, route_ids) do
    try do
      "gtfs-rt#{name}"
      |> via_tuple()
      |> GenServer.call({:query_alerts, stop, route_ids}, 10_000)
    rescue
      # A Registry that has stopped -- which is what a shutting-down node
      # looks like -- raises from the lookup before any call happens, where a
      # dead process would have exited. Catching only the exit left every
      # in-flight caller to crash on the way out of a deploy.
      ArgumentError -> []
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
    rescue
      # A Registry that has stopped -- which is what a shutting-down node
      # looks like -- raises from the lookup before any call happens, where a
      # dead process would have exited. Catching only the exit left every
      # in-flight caller to crash on the way out of a deploy.
      ArgumentError -> []
    catch
      :exit, _ -> []
    end
  end

  def get_current_vehicle_positions(name) do
    case RoomGtfs.RTIndex.vehicles(name) do
      {:ok, vehicles} ->
        vehicles

      :miss ->
        try do
          "gtfs-rt#{name}" |> via_tuple() |> GenServer.call(:query_vehicle_positions, 5_000)
        rescue
          # As above: a stopped Registry raises rather than exiting.
          ArgumentError -> []
        catch
          :exit, _ -> []
        end
    end
  end

  def get_current_vehicle_positions(name, trips, timeout \\ 5_000) do
    case RoomGtfs.RTIndex.vehicles(name, trips) do
      {:ok, vehicles} ->
        vehicles

      :miss ->
        "gtfs-rt#{name}" |> via_tuple() |> GenServer.call({:query_vehicle_positions, trips}, timeout)
    end
  end

  @doc """
  Whether a realtime trip id refers to a scheduled trip id.

  Usually they are the same string. NYCT sends the tail of it -- realtime
  "098600_5..S03R" against a schedule that says
  "ASP26GEN-1038-Sunday-00_098600_5..S03R", the leading part naming which
  published schedule the trip belongs to -- so an exact comparison finds
  nothing and those arrivals never show a live time.

  Off unless the source says so. A suffix comparison is looser and can match a
  trip it should not; a feed that needs it should declare it rather than have it
  guessed.
  """
  def trip_id_match?(config, scheduled, realtime)

  def trip_id_match?(_config, scheduled, realtime) when scheduled == realtime, do: true

  def trip_id_match?(%{rt_trip_id_suffix: true}, scheduled, realtime)
      when is_binary(scheduled) and is_binary(realtime) do
    String.ends_with?(scheduled, realtime)
  end

  def trip_id_match?(_config, _scheduled, _realtime), do: false

  @doc false
  # A realtime id against a whole list of scheduled ones. Exact matching gets a
  # MapSet; suffix matching cannot, and the lists it runs against are the trips
  # calling at one stop, so a scan is the right size of answer.
  def any_trip_match?(%{rt_trip_id_suffix: true} = config, scheduled_ids, realtime) do
    Enum.any?(scheduled_ids, &trip_id_match?(config, &1, realtime))
  end

  def any_trip_match?(_config, scheduled_ids, realtime) do
    realtime in scheduled_ids
  end

  @doc """
  What is leaving from near a foci, rather than from one named stop.

  Gathers the nearest few stops and asks each of them, then takes the
  soonest departures across the lot. The answer is deliberately blended: an
  area query asks what you can catch from here, not which pole to stand at,
  and the stops in a radius this size are usually the same corner.
  """
  def query_stop(id, %{mode: :area} = query) do
    inst = Configuration.get_source!(:bare, id)
    foci = Configuration.get_foci!(query.foci_id)

    stops =
      Storage.nearby_stops(id, foci.place, query.stops || 3, query.radius)
      |> Enum.map(& &1.stop_id)

    stops
    |> Enum.flat_map(fn stop ->
      Storage.get_upcoming_arrivals_for_stop(id, stop, @area_arrivals_per_stop, :now, inst.config.tz)
    end)
    |> Storage.fix_arrival_times()
    |> Enum.sort_by(& &1.arrival_time)
    |> Enum.take(@area_arrivals_total)
  end

  def query_stop(id, query) do
    # Bare: this wants the config blob, and nothing on this path reads the
    # mailboxes and webhooks the preloading version fetches alongside it.
    inst = Configuration.get_source!(:bare, id)
    # The source is already in hand, so its timezone goes with the call rather
    # than being looked up again inside it.
    res =
      Storage.get_upcoming_arrivals_for_stop(id, query.stop, 16, :now, inst.config.tz)
      |> Storage.fix_arrival_times

    # Not `url_rt_tu` alone: a source whose trip updates arrive in a combined
    # feed has that field blank and its URL in url_rt_shared, and gating on the
    # specific field skipped realtime entirely for exactly those sources.
    case RoomGtfs.Worker.RT.rt_url_for(inst.config, :tu) do
      nil ->
        res

      _val ->
        trips = res |> Enum.map(fn x -> x.trip_id end)

        case get_current_realtime(id, trips, query.stop, inst.config) do
          [] ->
            res

          rtvals ->
            # How full the vehicle is may be reported per stop in the trip
            # update, or only by the vehicle's own position report -- so the
            # positions are fetched once here to fall back on.
            vehicles = occupancy_vehicles(id, inst.config, trips)

            res
            |> Enum.map(fn x ->
              case Enum.find(rtvals, fn v ->
                     trip_id_match?(inst.config, x.trip_id, v.trip_id)
                   end) do
                nil ->
                  x

                val ->
                  stu = val.stop
                  time_event = stu && (stu.arrival || stu.departure)

                  x =
                    x
                    |> merge_occupancy(occupancy_for(inst.config, x.trip_id, stu, vehicles))
                    |> merge_schedule_relationship(val.schedule_relationship, stu)
                    |> merge_stop_properties(stu)

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
            |> resolve_assigned_platforms(id)
        end
    end
  end

  # How long to wait for vehicle positions before giving up on occupancy.
  #
  # Deliberately short. This is the second call query_stop makes to the same
  # worker -- get_current_realtime is the first -- and that worker also fetches
  # the feeds over HTTP, so the calls queue behind each other and behind the
  # fetches. At the default 30s a busy worker made every arrival query take
  # longer than the 30s tick of the vision that asked for it, so the vision
  # killed its own task and got nothing at all, every cycle.
  #
  # Occupancy is a nice-to-have hanging off an answer that has to arrive.
  # Waiting seconds for it, and losing the answer, is the wrong trade.
  @occupancy_timeout_ms 2_000

  # The vehicle positions for the trips calling at a stop, or [] for a source
  # that publishes none, or [] if they do not arrive promptly. A source with no
  # vehicle feed -- or a worker too busy to answer right now -- still gets
  # whatever the trip updates carry.
  defp occupancy_vehicles(id, config, trips) do
    case RoomGtfs.Worker.RT.rt_url_for(config, :vp) do
      nil ->
        []

      _val ->
        try do
          get_current_vehicle_positions(id, trips, @occupancy_timeout_ms)
        rescue
          ArgumentError -> []
        catch
          :exit, _ -> []
        end
    end
  end

  # An arrival says nothing about how full it is unless the feed did.
  defp merge_occupancy(arrival, nil), do: arrival

  defp merge_occupancy(arrival, %{status: status, pct: pct, carriages: carriages}) do
    arrival
    |> maybe_put(:occupancy, status)
    |> maybe_put(:occupancy_pct, pct)
    |> maybe_put(:carriages, presence(carriages))
  end

  # A key nothing was reported for is left off rather than set to nil, so that
  # "the feed did not say" and "the feed said nothing is there" stay
  # distinguishable further down.
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp presence([]), do: nil
  defp presence(""), do: nil
  defp presence(value), do: value

  @doc false
  # How full a vehicle is, as a GTFS-RT OccupancyStatus atom and, where the
  # feed says so, a percentage. The trip update may report the status per stop;
  # otherwise the vehicle's own position report says it for the whole trip, and
  # only that carries a percentage. NO_DATA_AVAILABLE is the feed declining to
  # answer, so it reads the same as an absent field -- NOT_ACCEPTING_PASSENGERS
  # is a real answer and is kept.
  def occupancy_for(config, scheduled_trip_id, stu, vehicles) do
    vehicle =
      Enum.find(vehicles, fn v ->
        v.trip_id && trip_id_match?(config, scheduled_trip_id, v.trip_id)
      end)

    status =
      occupancy_status(stu && stu.departure_occupancy_status) ||
        occupancy_status(vehicle && Map.get(vehicle, :occupancy_status))

    carriages = carriage_occupancy(vehicle)

    case {status, carriages} do
      {nil, []} ->
        nil

      {status, carriages} ->
        %{
          status: status,
          pct: occupancy_pct(vehicle && Map.get(vehicle, :occupancy_percentage)),
          carriages: carriages
        }
    end
  end

  @doc false
  # A train reporting each carriage separately is the difference between "the
  # train is full" and "walk to the back". Kept in the sequence the feed gives,
  # because that is the order they are coupled in and the whole point is which
  # end of the platform to stand at. A carriage the feed said nothing about
  # stays in the list -- a gap in the middle of a train is itself worth
  # drawing -- it simply has no occupancy.
  def carriage_occupancy(nil), do: []

  def carriage_occupancy(vehicle) do
    vehicle
    |> Map.get(:carriages)
    |> List.wrap()
    |> Enum.sort_by(&(&1.sequence || 0))
    |> Enum.map(fn c ->
      %{
        id: c.id,
        label: presence(c.label),
        sequence: c.sequence,
        occupancy: occupancy_status(c.occupancy_status),
        occupancy_pct: occupancy_pct(c.occupancy_percentage)
      }
    end)
  end

  # -1 is the protobuf default standing in for "not reported".
  defp occupancy_pct(pct) when is_integer(pct) and pct >= 0, do: pct
  defp occupancy_pct(_), do: nil

  @doc false
  # Two different ways an arrival is not going to happen, and they are not the
  # same thing: the trip may be cancelled outright, or it may be running fine
  # and simply not calling here. Both used to draw as an ordinary arrival,
  # which is the one wrong thing a departure board can do.
  #
  # SCHEDULED is the proto default and means "as published", so it is left off
  # rather than recorded -- only a departure from the schedule is news.
  def merge_schedule_relationship(arrival, trip_relationship, stu) do
    arrival
    |> maybe_put(:trip_status, relationship(trip_relationship))
    |> maybe_put(:stop_status, relationship(stu && stu.schedule_relationship))
  end

  defp relationship(nil), do: nil
  defp relationship(:SCHEDULED), do: nil
  defp relationship(rel) when is_atom(rel), do: rel
  # A feed may send a number outside the enum this was generated against.
  defp relationship(_), do: nil

  @doc false
  # What the feed says about this call specifically, rather than about the trip:
  # the track it has been given, and a headsign that overrides the trip's own.
  # A short-turn announces itself here -- the trip still says "Downtown" while
  # this particular call says it terminates early.
  def merge_stop_properties(arrival, nil), do: arrival

  def merge_stop_properties(arrival, stu) do
    props = Map.get(stu, :stop_time_properties)

    arrival
    |> maybe_put(:assigned_stop_id, props && presence(props.assigned_stop_id))
    |> maybe_put(:stop_headsign, props && presence(props.stop_headsign))
  end

  # A track is announced as a stop id, which is an internal string nobody wants
  # to read -- "127N" rather than "Track 3". The static feed knows what that
  # stop is called, so the ids are resolved together in one query rather than
  # one per arrival, and an id the static feed has never heard of is shown as
  # itself rather than dropped.
  defp resolve_assigned_platforms(arrivals, source_id) do
    ids =
      arrivals
      |> Enum.map(&Map.get(&1, :assigned_stop_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case ids do
      [] ->
        arrivals

      ids ->
        stops = Storage.get_stops_by_ids(source_id, ids)

        Enum.map(arrivals, fn a ->
          case Map.get(a, :assigned_stop_id) do
            nil -> a
            id -> Map.put(a, :assigned_platform, platform_label(Map.get(stops, id)) || id)
          end
        end)
    end
  end

  defp platform_label(nil), do: nil

  defp platform_label(stop) do
    presence(stop.platform_code) || presence(stop.platform_name) || presence(stop.stop_name)
  end

  defp occupancy_status(nil), do: nil
  defp occupancy_status(:NO_DATA_AVAILABLE), do: nil
  defp occupancy_status(status) when is_atom(status), do: status

  # A feed may send a number outside the enum the generated module knows; that
  # is not an occupancy anyone can draw, so it reads as no answer.
  defp occupancy_status(status) when is_integer(status) do
    try do
      TransitRealtime.VehiclePosition.OccupancyStatus.key(status) |> occupancy_status()
    rescue
      _ -> nil
    end
  end

  # etc
  def init(opts) do
    Configuration.subscribe(:source, opts[:name])

    Periodic.start_link(
      # A backstop, not the mechanism: an edit to the source arrives by
      # broadcast the moment it is written. This only catches a write that
      # never went through Configuration -- a migration, or a hand at a psql
      # prompt.
      every: :timer.seconds(60),
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

  # Told rather than asked: the same refresh, run when somebody edits the
  # source instead of every four seconds in case they did.
  def handle_info({:cfg_changed, :source, _id}, state) do
    handle_cast(:refresh_db_cfg, state)
  end

  def handle_info(_msg, state), do: {:noreply, state}

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

  @doc """
  The row counts behind a source, for the stats card.

  Every one of these is an exact `count(*)` over a table filtered to one
  source, and two of those tables hold millions of rows -- five million stop
  times and half a million shape points for one MBTA feed. Asked one after
  another that is several seconds of database work before anything renders,
  which is what made the button time out.

  So: asked together, and the answer held for a minute. They change when a feed
  imports and not otherwise, so the worst a stale one can be is a count from
  before the import currently running -- which the queue page is there to show.
  """
  def source_stats(id) do
    case RoomSanctum.QueryCache.fetch({:source_stats, id}, fn -> gather_stats(id) end, 60_000) do
      {:ok, stats} -> stats
      # Someone else is already gathering them. Saying so beats waiting several
      # seconds to say the same thing.
      :busy -> %{gathering: true}
    end
  end

  @stat_names [
    :calendars,
    :calendar_dates,
    :services_today,
    :trips_no_service,
    :directions,
    :routes,
    :shapes,
    :stops,
    :stop_times,
    :trips,
    :rt
  ]

  defp gather_stats(id) do
    [
      fn -> Storage.count_calendars(id) end,
      fn -> Storage.count_calendar_dates(id) end,
      fn -> services_today(id) end,
      fn -> Storage.count_trips_without_service(id) end,
      fn -> Storage.count_directions(id) end,
      fn -> Storage.count_routes(id) end,
      fn -> Storage.count_shapes(id) end,
      fn -> Storage.count_stops(id) end,
      fn -> Storage.count_stop_times(id) end,
      fn -> Storage.count_trips(id) end,
      fn -> RoomGtfs.Worker.RT.stats(id) end
    ]
    |> Task.async_stream(& &1.(),
      max_concurrency: 4,
      timeout: 20_000,
      on_timeout: :kill_task
    )
    |> Enum.zip(@stat_names)
    |> Enum.map(fn
      {{:ok, value}, name} -> {name, value}
      # One count that will not answer should not cost the other ten.
      {{:exit, _reason}, name} -> {name, :unavailable}
    end)
    |> Enum.into(%{})
  end


  # In the source's own timezone: a board in Boston rolls over to the next
  # service day at midnight there, not at midnight UTC, and for part of every
  # day the two disagree about which services are running.
  defp services_today(id) do
    tz =
      case Configuration.get_source!(:bare, id) do
        %{config: %{tz: tz}} when is_binary(tz) -> tz
        _otherwise -> "Etc/UTC"
      end

    tz
    |> DateTime.now!()
    |> DateTime.to_date()
    |> then(&Storage.services_on(id, &1))
    |> MapSet.size()
  rescue
    _ -> 0
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

  # What a kind polls at when the source has not said. One request a minute per
  # kind is fresh enough for a bus and cheap enough for a metered feed to be
  # worth a second look before lowering.
  @default_rt_period :timer.seconds(60)

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
    rescue
      # A Registry that has stopped -- which is what a shutting-down node
      # looks like -- raises from the lookup before any call happens, where a
      # dead process would have exited. Catching only the exit left every
      # in-flight caller to crash on the way out of a deploy.
      ArgumentError -> %{rt_sa: :unavailable, rt_tu: :unavailable, rt_vp: :unavailable}
    catch
      :exit, _ -> %{rt_sa: :unavailable, rt_tu: :unavailable, rt_vp: :unavailable}
    end
  end

  def init(opts) do
    Configuration.subscribe(:source, opts[:name])

    Periodic.start_link(
      # A backstop, not the mechanism: an edit to the source arrives by
      # broadcast the moment it is written. This only catches a write that
      # never went through Configuration -- a migration, or a hand at a psql
      # prompt.
      every: :timer.seconds(60),
      run: fn -> RoomGtfs.Worker.RT.refresh_db_cfg(opts[:name]) end,
      initial_delay: :timer.seconds(10)
    )

    Periodic.start_link(
      # 15s because that is the finest interval a source can be set to, and the
      # tick is the floor on all of them. Every kind that is not due returns
      # immediately, so the extra ticks cost a message and a map lookup.
      every: :timer.seconds(15),
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
       stops_at: nil,
       # kind => when it was last polled; each has its own interval.
       rt_polled_at: %{}
     }}
  end

  defp bcast(id, :disabled) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, :disabled})
  end

  # Every realtime fetch goes through here so that the outcome is recorded
  # whether it worked or not. The logs already say when one fails; what they
  # cannot say is that a feed stopped being fetched at all, which is the failure
  # that looks exactly like silence. See RoomGtfs.FeedHealth.
  # A source polling every three minutes can happily use data up to three
  # minutes old, and several sources sharing one URL -- which is the whole point
  # of the regional feed -- then fetch it once between them instead of once each.
  defp record_health(state, kind, url, result, took) do
    RoomGtfs.FeedHealth.record(state.id, state.inst && state.inst.name, kind, url, result, took)
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
            severity:    alert.severity_level |> to_string(),
            # Whether the alert names this stop, as opposed to reaching it by
            # naming the line it is on. "Elevator out here" and "delays on the
            # Red Line" are both true of the stop and are not the same news.
            stop_specific:
              Enum.any?(alert.informed_entity, fn e -> e.stop_id != nil and e.stop_id == stop end)
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

  # The occupancy of each carriage, as the feed sent it -- the enum values are
  # left raw here, the same as the vehicle's own occupancy_status, and are
  # normalised once where they are read.
  defp carriage_details(v) do
    v
    |> Map.get(:multi_carriage_details)
    |> List.wrap()
    |> Enum.map(fn c ->
      %{
        id: c.id,
        label: c.label,
        sequence: c.carriage_sequence,
        occupancy_status: c.occupancy_status,
        occupancy_percentage: c.occupancy_percentage
      }
    end)
  end

  defp place_vehicle(v, stops) do
    base = %{
      vehicle_id: v.vehicle && v.vehicle.id,
      trip_id: v.trip && v.trip.trip_id,
      route_id: v.trip && v.trip.route_id,
      stop_id: v.stop_id,
      current_status: v.current_status,
      occupancy_status: v.occupancy_status,
      occupancy_percentage: v.occupancy_percentage,
      carriages: carriage_details(v),
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
    do_update_realtime(state)
  end

  # Told rather than asked: the same refresh, run when somebody edits the
  # source instead of every four seconds in case they did.
  def handle_info({:cfg_changed, :source, _id}, state) do
    handle_cast(:refresh_db_cfg, state)
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Each kind keeps its own clock. Trip updates go stale in seconds; service
  # alerts change a few times a day, and polling them as often as vehicle
  # positions buys nothing and costs a request -- which matters where the feed
  # is metered, and is simply waste where it is not.
  #
  # Gated here rather than by rescheduling the Periodic, which cannot be changed
  # once started and would have to be torn down and rebuilt on every config
  # refresh.
  defp due?(state, url, period) do
    case state |> Map.get(:rt_polled_at, %{}) |> Map.get(url) do
      nil -> true
      at -> System.monotonic_time(:millisecond) - at >= period
    end
  end

  defp mark_polled(state, url) do
    polled =
      state |> Map.get(:rt_polled_at, %{}) |> Map.put(url, System.monotonic_time(:millisecond))

    Map.put(state, :rt_polled_at, polled)
  end

  defp rt_period_ms(state, kind) do
    state.inst
    |> case do
      %{config: config} -> Map.get(config, period_field(kind))
      _ -> nil
    end
    |> case do
      seconds when is_integer(seconds) -> :timer.seconds(seconds)
      _ -> @default_rt_period
    end
  end

  defp period_field(:tu), do: :rt_period_tu
  defp period_field(:vp), do: :rt_period_vp
  defp period_field(:sa), do: :rt_period_sa

  defp do_update_realtime(state) do
    state =
      if state.inst.enabled do
        state.inst.config
        |> rt_groups()
        |> Enum.reduce(state, &fetch_group/2)
      else
        bcast(state.id, :disabled)
        state
      end

    {:noreply, state}
  end

  @doc """
  The kinds this source reads, grouped by the URL they come from.

  A URL is the unit of scheduling, not a kind. Where three kinds have three
  feeds that is the same thing; where one feed carries all three -- the MTA's
  subway feeds -- it very much is not. Polling those kinds independently meant
  fetching the same URL on the fastest of their three clocks and then handing
  the slower kinds whatever the cache still held, so vehicle positions could be
  minutes stale while trip updates from the very same message were seconds old.
  Nothing was saved by it: the request had already been made.

  Grouped, one fetch updates everything that came in it.
  """
  def rt_groups(config) do
    [:tu, :vp, :sa]
    |> Enum.map(fn kind -> {kind, rt_url(config, kind)} end)
    |> Enum.reject(fn {_kind, url} -> url in [nil, ""] end)
    |> Enum.reduce([], fn {kind, url}, acc ->
      case List.keyfind(acc, url, 0) do
        nil -> acc ++ [{url, [kind]}]
        {^url, kinds} -> List.keyreplace(acc, url, 0, {url, kinds ++ [kind]})
      end
    end)
  end

  defp fetch_group({url, kinds}, state) do
    # The fastest kind in the group wins: the URL is fetched that often, and
    # every kind in it is that fresh. Only reachable by hand-editing the config,
    # since the form offers one control per group.
    period = kinds |> Enum.map(&rt_period_ms(state, &1)) |> Enum.min()

    if due?(state, url, period) do
      state |> mark_polled(url) |> do_fetch_group(url, kinds, period)
    else
      state
    end
  end

  defp do_fetch_group(state, url, kinds, period) do
    started = System.monotonic_time(:millisecond)
    result = FeedCache.get(url, max(period - :timer.seconds(5), :timer.seconds(1)))
    took = System.monotonic_time(:millisecond) - started

    case result do
      {:ok, feed} when is_struct(feed, TransitRealtime.FeedMessage) ->
        feed = for_this_agency(feed, state)

        Enum.reduce(kinds, state, fn kind, acc ->
          # Narrowed before it is recorded, so health reports what this kind
          # actually got. Recording the whole message would have every kind of a
          # combined feed claim the same entity count -- exactly the reading
          # that means "the same URL is in all three fields by mistake", and
          # would say it about a correct configuration.
          sliced = slice(feed, entity_field(kind))

          # Health records the delta, not the running total: what this poll
          # actually received is the honest reading of whether the feed is
          # alive, and a differential feed reporting "nothing changed" has
          # genuinely received nothing.
          record_health(acc, kind, url, {:ok, sliced}, took)
          store_feed(acc, kind, merge_feed(current_feed(acc, kind), sliced))
        end)

      {:error, error} ->
        Enum.each(kinds, &record_health(state, &1, url, result, took))

        Logger.info(
          "failed to fetch gtfs-rt url#{inspect(kinds)} for '#{state.inst.name}', reason: #{inspect(error)}"
        )

        state
    end
  end

  # Where each kind comes from. A kind with no URL of its own falls back to the
  # combined feed, so an agency publishing everything in one message -- the MTA
  # subway feeds are 67 trip updates, 45 vehicle positions and an alert in a
  # single URL -- names it once instead of three times. Specific beats general,
  # so a combined feed plus a dedicated alerts feed works too.
  @doc """
  Where a kind's feed comes from: its own URL, or the combined one behind it.

  Public because the question is asked outside the poller too -- `query_stop/2`
  has to know whether trip updates exist at all before it goes looking for them,
  and asking `url_rt_tu` directly gets the wrong answer for a combined feed.
  """
  def rt_url_for(config, kind)

  def rt_url_for(config, :sa), do: blank(Map.get(config, :url_rt_sa)) || blank(Map.get(config, :url_rt_shared))
  def rt_url_for(config, :tu), do: blank(Map.get(config, :url_rt_tu)) || blank(Map.get(config, :url_rt_shared))
  def rt_url_for(config, :vp), do: blank(Map.get(config, :url_rt_vp)) || blank(Map.get(config, :url_rt_shared))

  defp blank(nil), do: nil
  defp blank(""), do: nil
  defp blank(value), do: value

  defp rt_url(config, kind), do: rt_url_for(config, kind)

  defp entity_field(:sa), do: :alert
  defp entity_field(:tu), do: :trip_update
  defp entity_field(:vp), do: :vehicle

  # Sliced to the kind it is being held as, always -- not only for a combined
  # feed. Three sources pointing at one mixed URL used to store the whole feed
  # three times, so the health metrics reported the same entity count for all
  # three kinds, which is indistinguishable from having pasted the same URL into
  # all three fields by mistake. Sliced, subway reads 67/45/1 and says what it
  # actually has. The query handlers filter by kind anyway, so this changes
  # nothing they see.
  defp store_feed(state, :sa, feed), do: Map.put(state, :rt_sa, feed)

  defp store_feed(state, :tu, feed) do
    RoomGtfs.RTIndex.put_trip_updates(state.id, feed.entity)
    Map.put(state, :rt_tu, feed)
  end

  defp store_feed(state, :vp, feed) do
    state = state |> Map.put(:rt_vp, feed) |> ensure_stops()
    vehicles = vehicle_positions_from(feed, state.stops)
    RoomGtfs.RTIndex.put_vehicles(state.id, vehicles)

    # The source page watches its own channel; the query pages watch the shared
    # one and sort out which vehicles are theirs.
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      "gtfs_vehicle_positions:#{state.id}",
      {:vehicle_positions_updated, state.id, vehicles}
    )

    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      "gtfs_vehicle_positions",
      {:vehicle_positions_updated, vehicles}
    )

    state
  end

  defp slice(feed, field) do
    %{feed | entity: Enum.filter(feed.entity, &Map.get(&1, field))}
  end

  defp current_feed(state, :sa), do: state.rt_sa
  defp current_feed(state, :tu), do: state.rt_tu
  defp current_feed(state, :vp), do: state.rt_vp

  @doc """
  What to hold after a poll, given what was held before it.

  GTFS-RT publishes in one of two modes, and they mean opposite things by the
  same message. A **full dataset** is a snapshot: what arrived is the whole
  truth and replaces whatever was held. A **differential** feed is a stream of
  edits against a feed held open -- each message carries only what changed,
  entities are keyed by `FeedEntity.id`, and `is_deleted` means drop this one.

  Replacing on every poll, which is what used to happen, is right for the first
  and silently wrong for the second: everything not restated in the newest
  delta disappears, so a differential source would show a handful of vehicles
  and no explanation.

  Order is kept stable -- entities already held stay where they were and new
  ones join the end -- so that a feed does not appear to reshuffle itself on
  every poll.

  A differential message with nothing held yet is applied to an empty feed,
  which is the only sensible reading: there is no earlier state to edit, so
  what arrives is what there is, minus anything it deletes.
  """
  def merge_feed(previous, incoming) do
    if differential?(incoming) do
      %{incoming | entity: merge_entities(entities(previous), incoming.entity)}
    else
      incoming
    end
  end

  defp differential?(feed) do
    feed.header && feed.header.incrementality == :DIFFERENTIAL
  end

  defp entities(nil), do: []
  defp entities(feed), do: feed.entity

  defp merge_entities(held, delta) do
    initial = {held |> Enum.map(& &1.id) |> Enum.reverse(), Map.new(held, &{&1.id, &1})}

    # Folded in order, so a message that deletes an entity and then sends it
    # again -- or sends it twice -- ends up with what it said last.
    {order, current} =
      Enum.reduce(delta, initial, fn entity, {order, current} ->
        cond do
          entity.is_deleted -> {order, Map.delete(current, entity.id)}
          Map.has_key?(current, entity.id) -> {order, Map.put(current, entity.id, entity)}
          true -> {[entity.id | order], Map.put(current, entity.id, entity)}
        end
      end)

    order
    |> Enum.reverse()
    |> Enum.uniq()
    |> Enum.flat_map(fn id ->
      case Map.fetch(current, id) do
        {:ok, entity} -> [entity]
        :error -> []
      end
    end)
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
              RoomGtfs.Worker.any_trip_match?(
                state.inst && state.inst.config,
                trips,
                x.trip_update.trip.trip_id
              )
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
      |> Enum.filter(
        &(&1.trip_id &&
            RoomGtfs.Worker.any_trip_match?(state.inst && state.inst.config, trips, &1.trip_id))
      )

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
  # file_to_order/1 accept. Everything else in a feed -- feed_info.txt,
  # linked_datasets.txt -- is either handled separately or ignored.
  @import_files ~w(
    agency.txt
    calendar.txt
    calendar_dates.txt
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
      :calendar_dates -> RoomSanctum.Storage.truncate_calendar_date(id)
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
        :calendar_dates -> {:gtfs_calendar_dates, [GTFS.CalendarDate |> get_cols(cols_j_plus)], GTFS.CalendarDate |> get_cols_pgtypes(cols_j_plus)}
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

      "calendar_dates.txt" ->
        :calendar_dates

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
      "calendar_dates.txt" -> 5
      "directions.txt" -> 6
      "routes.txt" -> 7
      "shapes.txt" -> 8
      "stops.txt" -> 9
      "stop_times.txt" -> 10
      "trips.txt" -> 11
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

                bcast(id, type, file_to_order(e.file_name), 12)

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
