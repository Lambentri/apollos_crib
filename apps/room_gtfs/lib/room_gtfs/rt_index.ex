defmodule RoomGtfs.RTIndex do
  @moduledoc """
  The realtime feeds, indexed by trip and readable without asking anyone.

  Arrivals used to be answered by two `GenServer.call`s into the source's RT
  worker -- one for trip updates, one for vehicle positions. That worker also
  fetches the feeds over HTTP, so the calls queued behind each other and behind
  the fetches, and a stop lookup could take tens of seconds. The vision that
  asked for it gives up after 30 and kills its own task, so a busy source meant
  a board that showed nothing at all.

  A realtime feed is immutable data replaced on a timer, which is the shape ETS
  is for. Readers take what they need straight out of the table; nothing
  serialises behind the worker's own work.

  Indexed by trip rather than stored whole, deliberately. A `:tu` feed is ~1600
  entities, and handing a reader all of them to find its sixteen would copy far
  more than the GenServer ever did -- the call at least filtered before
  replying. One row per trip, holding only the fields anything reads, means a
  lookup copies sixteen small maps.

  The table is public so each source's worker writes its own rows, and owned by
  this app's supervisor rather than by a worker, so a worker restarting does
  not take the data with it.
  """

  @table :gtfs_rt_index

  def table, do: @table

  @doc false
  def child_spec(_opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}}
  end

  @doc false
  def start_link do
    Task.start_link(fn ->
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
      Process.hibernate(Process, :sleep, [:infinity])
    end)
  end

  @doc """
  Replace a source's trip updates with what just arrived.

  Written as one row per trip, carrying only what a stop lookup reads: the
  trip's own identity and relationship, and its stop times keyed by stop id.
  """
  def put_trip_updates(source_id, entities) do
    rows =
      entities
      |> Enum.filter(&(&1.trip_update && &1.trip_update.trip && &1.trip_update.trip.trip_id))
      |> Enum.map(fn %{trip_update: tu} ->
        {{source_id, :tu, tu.trip.trip_id},
         %{
           trip_id: tu.trip.trip_id,
           schedule_relationship: tu.trip.schedule_relationship,
           timestamp: tu.timestamp,
           stops: stops_by_id(tu.stop_time_update)
         }}
      end)

    replace(source_id, :tu, rows)
  end

  @doc """
  Replace a source's vehicle positions.

  Kept twice over: a row per trip, for "the vehicle on this trip", and one row
  holding the lot, for the map. The second is a large copy on read and is only
  taken by callers that genuinely want every vehicle.
  """
  def put_vehicles(source_id, vehicles) do
    rows =
      vehicles
      |> Enum.filter(& &1.trip_id)
      |> Enum.map(&{{source_id, :vp, &1.trip_id}, &1})

    replace(source_id, :vp, rows)
    :ets.insert(@table, {{source_id, :vp_all}, vehicles})
    :ok
  end

  @doc """
  The trip updates for a set of scheduled trip ids, at one stop.

  Answers `{:ok, list}` when the source has a feed indexed, and `:miss` when it
  has none -- so a caller can tell "nothing is running" from "ask the worker
  instead", which is what a source whose feed has never been stored needs.
  """
  def trip_updates(source_id, trip_ids, stop_id) do
    case indexed?(source_id, :tu) do
      false ->
        :miss

      true ->
        found =
          trip_ids
          |> Enum.flat_map(&:ets.lookup(@table, {source_id, :tu, &1}))
          |> Enum.map(fn {_k, tu} -> Map.put(tu, :stop, Map.get(tu.stops, stop_id)) end)

        {:ok, found}
    end
  end

  @doc """
  The trip updates for a set of scheduled trip ids where the feed names trips
  by a suffix of the scheduled id -- NYCT's shape, which no key lookup matches.

  A scan of one source's rows, which is still cheaper than a call into a busy
  worker, and only sources that declare the suffix take this path.
  """
  def trip_updates_by_suffix(source_id, trip_ids, stop_id) do
    case indexed?(source_id, :tu) do
      false ->
        :miss

      true ->
        found =
          @table
          |> :ets.match_object({{source_id, :tu, :_}, :_})
          |> Enum.filter(fn {{_, _, rt_id}, _} ->
            Enum.any?(trip_ids, &String.ends_with?(&1, rt_id))
          end)
          |> Enum.map(fn {_k, tu} -> Map.put(tu, :stop, Map.get(tu.stops, stop_id)) end)

        {:ok, found}
    end
  end

  @doc """
  The vehicles on a set of trips, or every vehicle the source is reporting.
  """
  def vehicles(source_id, trip_ids) do
    case indexed?(source_id, :vp) do
      false -> :miss
      true -> {:ok, Enum.flat_map(trip_ids, &(:ets.lookup(@table, {source_id, :vp, &1}) |> Enum.map(fn {_k, v} -> v end)))}
    end
  end

  def vehicles(source_id) do
    case :ets.lookup(@table, {source_id, :vp_all}) do
      [{_k, vehicles}] -> {:ok, vehicles}
      [] -> :miss
    end
  end

  @doc false
  # Whether this source has ever stored a feed of this kind. Distinct from
  # having no rows: a feed can legitimately arrive carrying nothing.
  def indexed?(source_id, kind) do
    :ets.member(@table, {source_id, {:present, kind}})
  end

  # The marker is a two-element key on purpose: the per-trip rows are scanned
  # with a three-element pattern for suffix matching, and a marker shaped like
  # one of them comes back from that scan as a trip whose id is an atom.
  defp replace(source_id, kind, rows) do
    :ets.match_delete(@table, {{source_id, kind, :_}, :_})
    :ets.insert(@table, rows)
    :ets.insert(@table, {{source_id, {:present, kind}}, true})
    :ok
  end

  # A trip calls at a stop once in the ordinary case; a loop route can call
  # twice, and the earlier call is the one an arrivals board wants.
  defp stops_by_id(stop_time_updates) do
    stop_time_updates
    |> List.wrap()
    |> Enum.reject(&(&1.stop_id in [nil, ""]))
    |> Enum.reverse()
    |> Map.new(fn stu ->
      {stu.stop_id,
       %{
         arrival: stu.arrival,
         departure: stu.departure,
         schedule_relationship: stu.schedule_relationship,
         stop_time_properties: stu.stop_time_properties,
         departure_occupancy_status: stu.departure_occupancy_status
       }}
    end)
  end
end
