defmodule RoomSanctum.Worker.Vision do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("vision" <> opts[:id]))
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(4),
      run: fn -> RoomSanctum.Worker.Vision.refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(30),
      run: fn -> RoomSanctum.Worker.Vision.query_workers(opts[:id]) end,
      initial_delay: 100
    )

    {:ok, %{id: opts[:id], vision: nil, vision_q: [], data: [], query_task: nil}}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  # Public
  def refresh_db_cfg(name) do
    "vision#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def query_workers(name) do
    "vision#{name}"
    |> via_tuple()
    |> GenServer.cast(:query_workers)
  end

  def get_state(name) do
    "vision#{name}"
    |> via_tuple
    |> GenServer.call(:return_state, 15_000)
  end

  #

  def handle_cast(:refresh_db_cfg, state) do
    v = Configuration.get_vision!(state[:id])
    queries = v.queries |> Enum.map(fn x -> x.data.query end) |> Configuration.get_queries!()
    {:noreply, state |> Map.put(:vision, v) |> Map.put(:vision_q, queries)}
  end

  def handle_cast(:query_workers, state) do
    # todo filter out things deemed irrelevant by various timers
    # Cancel previous task if still running
    if state.query_task && Process.alive?(state.query_task.pid) do
      Task.shutdown(state.query_task, :brutal_kill)
    end

    # Start async task to query workers
    task =
      Task.async(fn ->
        query_all_workers(state.vision_q)
      end)

    {:noreply, state |> Map.put(:query_task, task)}
  end

  # Handle async task completion
  def handle_info({ref, queried_data}, state) do
    # Task completed successfully
    Process.demonitor(ref, [:flush])
    {:noreply, state |> Map.put(:data, queried_data)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task crashed or was killed, keep previous data
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call(:return_state, _from, state) do
    response = %{
      data: state.data,
      queries: state.vision_q,
      name: if(state.vision, do: state.vision.name, else: "Unknown")
    }
    {:reply, response, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  # Private helper to query all workers
  defp query_all_workers(vision_q) do
    vision_q
    |> Enum.map(fn q ->
      r =
        case q.source.type do
          :gtfs ->
            RoomGtfs.Worker.query_stop(q.source.id, q.query)

          :gbfs ->
            RoomGbfs.Worker.query_stop(q.source.id, q.query)

          :tidal ->
            RoomTidal.Worker.query_tides(q.source.id, q.query)

          :weather ->
            RoomWeather.Worker.query_weather(
              q.source.id,
              q.query
            )

          :aqi ->
            RoomAirQuality.Worker.query_place(
              q.source.id,
              q.query
            )

          :ephem ->
            RoomEphem.Worker.query_ephem(
              q.source.id,
              q.query
            )

          :calendar ->
            RoomCalendar.Worker.query_calendar(
              q.source.id,
              q.query
            )

          :cronos ->
            RoomCronos.Worker.query_cronos(q.id, q.query)

          :gitlab ->
            case RoomGitlab.Worker.pid(q.source.id) do
              nil -> []
              _val -> (Process.alive?(RoomGitlab.Worker.pid(q.source.id)) &&
                         RoomGitlab.Worker.read_jobs(q.source.id, q.query)) || []
            end

          :packages ->
            RoomPackages.Worker.read(q.source.id, q.query)
        end

      {{q.id, q.source.type}, r}
    end)
    |> Enum.into(%{})
  end
end
