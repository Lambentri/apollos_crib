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

    {:ok, %{id: opts[:id], vision: nil, vision_q: [], data: []}}
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
    |> GenServer.call(:return_state)
  end

  #

  def handle_cast(:refresh_db_cfg, state) do
    v = Configuration.get_vision!(state[:id])
    queries = v.queries |> Enum.map(fn x -> x.data.query end) |> Configuration.get_queries!()
    {:noreply, state |> Map.put(:vision, v) |> Map.put(:vision_q, queries)}
  end

  def handle_cast(:query_workers, state) do
    # todo filter out things deemed irrelevant by various timers
    queried =
      state.vision_q
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
              val ->  (Process.alive?(RoomGitlab.Worker.pid(q.source.id)) &&
                         RoomGitlab.Worker.read_jobs(q.source.id, q.query)) || []
            end
          end

        {{q.id, q.source.type}, r}
      end)
      |> Enum.into(%{})

    {:noreply, state |> Map.put(:data, queried)}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call(:return_state, _from, state) do
    {:reply, %{data: state.data, queries: state.vision_q, name: state.vision.name}, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end
end
