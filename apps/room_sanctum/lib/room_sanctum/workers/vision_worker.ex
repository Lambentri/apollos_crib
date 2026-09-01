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
    Process.flag(:trap_exit, true)

    Configuration.subscribe(:vision, opts[:id])

    Periodic.start_link(
      # A backstop, not the mechanism: config changes arrive by broadcast the
      # moment they are written. This only catches a write that never went
      # through Configuration -- a migration, or a hand at a psql prompt.
      every: :timer.seconds(60),
      run: fn -> RoomSanctum.Worker.Vision.refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(30),
      run: fn -> RoomSanctum.Worker.Vision.query_workers(opts[:id]) end,
      initial_delay: 100
    )

    {:ok, %{id: opts[:id], vision: nil, vision_q: [], data: %{}, query_task: nil}}
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
  # Told rather than asked: the same refresh, run when somebody edits the
  # vision instead of every four seconds in case they did.
  def handle_info({:cfg_changed, :vision, _id}, state) do
    handle_cast(:refresh_db_cfg, state)
  end

  def handle_info({ref, queried_data}, state) do
    # Task completed successfully
    Process.demonitor(ref, [:flush])
    {:noreply, state |> Map.put(:data, queried_data)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task crashed or was killed, keep previous data
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    if state.query_task && state.query_task.pid == pid and reason != :normal do
      Logger.warning("Vision query task crashed: #{inspect(reason)}; keeping previous data")
    end

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
  # A vision's queries reach different workers over different networks, and
  # asking them one after another spends the sum of their latencies. That
  # matters because handle_cast(:query_workers) kills the previous task when
  # the next tick arrives: one slow query does not merely arrive late, it
  # destroys the whole round, including the answers that had already come back.
  # In prod that showed up as a board with nothing on it and a steady three
  # cancelled statements a minute -- the GTFS query was simply the one holding
  # a database connection when the axe fell.
  #
  # Asked together, the round costs the slowest query rather than all of them,
  # and a query that overruns yields nothing for itself alone.
  @query_concurrency 4
  @query_timeout_ms 10_000

  defp query_all_workers(vision_q) do
    vision_q
    |> Task.async_stream(&query_safely/1,
      max_concurrency: @query_concurrency,
      timeout: @query_timeout_ms,
      on_timeout: :kill_task
    )
    |> Enum.zip(vision_q)
    |> Enum.map(fn
      {{:ok, result}, q} ->
        {{q.id, q.source.type}, result}

      {{:exit, reason}, q} ->
        # Its own failure, not everyone else's.
        Logger.warning(
          "Query gave up for #{inspect(q.source.type)} (#{q.source.id}): #{inspect(reason)}"
        )

        {{q.id, q.source.type}, []}
    end)
    |> Enum.into(%{})
  end

  defp query_safely(q) do
    query_one(q)
  rescue
    e ->
      Logger.warning(
        "Query failed for #{inspect(q.source.type)} (#{q.source.id}): #{Exception.message(e)}"
      )

      []
  catch
    kind, reason ->
      Logger.warning(
        "Query #{kind} for #{inspect(q.source.type)} (#{q.source.id}): #{inspect(reason)}"
      )

      []
  end

  defp query_one(q) do
    case q.source.type do
      :gtfs ->
        RoomGtfs.Worker.query_stop(q.source.id, q.query)

      :gbfs ->
        RoomGbfs.Worker.query_stop(q.source.id, q.query)

      :tidal ->
        RoomTidal.Worker.query_tides(q.source.id, q.query)

      :weather ->
        RoomWeather.Worker.query_weather(q.source.id, q.query)

      :aqi ->
        RoomAirQuality.Worker.query_place(q.source.id, q.query)

      :ephem ->
        RoomEphem.Worker.query_ephem(q.source.id, q.query)

      :calendar ->
        RoomCalendar.Worker.query_calendar(q.source.id, q.query)

      :cronos ->
        RoomCronos.Worker.query_cronos(q.id, q.query)

      :gitlab ->
        case RoomGitlab.Worker.pid(q.source.id) do
          nil ->
            []

          _val ->
            (Process.alive?(RoomGitlab.Worker.pid(q.source.id)) &&
               RoomGitlab.Worker.read_jobs(q.source.id, q.query)) || []
        end

      :github ->
        case RoomGithub.Worker.pid(q.source.id) do
          nil ->
            []

          _val ->
            level = Map.get(q.query, :level) || Map.get(q.query, "level") || "runs"

            if Process.alive?(RoomGithub.Worker.pid(q.source.id)) do
              case level do
                "jobs" -> RoomGithub.Worker.read_jobs(q.source.id, q.query)
                _ -> RoomGithub.Worker.read_runs(q.source.id, q.query)
              end
            else
              []
            end
        end

      :packages ->
        RoomPackages.Worker.read(q.source.id, q.query)

      :drought ->
        case RoomDrought.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomDrought.Worker.read(q.source.id, q.query) || []
        end

      :pollen ->
        case RoomPollen.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomPollen.Worker.read(q.source.id, q.query) || []
        end

      :icarus ->
        case RoomIcarus.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomIcarus.Worker.read(q.source.id, q.query) || []
        end

      :mailbox ->
        case RoomHermes.Mail.ImapWorker.pid(q.source.id) do
          nil -> []
          _pid -> RoomHermes.Mail.ImapWorker.read(q.source.id, q.query) || []
        end

      :treasury ->
        case RoomTreasury.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomTreasury.Worker.read(q.source.id, q.query) || []
        end

      :bourse ->
        case RoomBourse.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomBourse.Worker.read(q.source.id, q.query) || []
        end
    end
  end
end
