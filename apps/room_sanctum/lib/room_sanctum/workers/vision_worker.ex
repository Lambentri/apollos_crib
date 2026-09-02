defmodule RoomSanctum.Worker.Vision do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus

  # Each query is asked on its own, so this is the cap on one of them rather
  # than on a round of them.
  @query_timeout_ms 10_000


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

    {:ok,
     %{
       id: opts[:id],
       vision: nil,
       vision_q: [],
       # Answers, and when each one arrived. Held per query rather than as one
       # map replaced wholesale, so a source that is slow or briefly broken
       # costs only its own panel.
       data: %{},
       data_at: %{},
       # ref => %{key:, task:, timer:} for the queries currently out.
       inflight: %{}
     }}
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

  # One task per query, each reporting on its own.
  #
  # This used to be a single task producing the whole map, which meant the
  # board did not move until the slowest source had answered, and the next
  # tick killed the round outright if it had not -- throwing away the answers
  # that had already come back. A source that is slow now costs its own panel
  # and nothing else.
  #
  # A query still out from the last round is not asked again. That is the
  # backpressure the brutal kill was standing in for, and unlike the kill it
  # does not destroy work in progress.
  def handle_cast(:query_workers, state) do
    outstanding = state.inflight |> Map.values() |> MapSet.new(& &1.key)

    state =
      Enum.reduce(state.vision_q, state, fn q, acc ->
        key = {q.id, q.source.type}

        if MapSet.member?(outstanding, key) do
          Logger.debug("Vision #{state.id}: #{inspect(key)} still out, not asking again")
          acc
        else
          start_query(acc, q, key)
        end
      end)

    {:noreply, state}
  end

  defp start_query(state, q, key) do
    task = Task.async(fn -> query_safely(q) end)
    timer = Process.send_after(self(), {:query_overran, task.ref}, @query_timeout_ms)

    put_in(state.inflight[task.ref], %{key: key, task: task, timer: timer})
  end

  # Handle async task completion
  # Told rather than asked: the same refresh, run when somebody edits the
  # vision instead of every four seconds in case they did.
  def handle_info({:cfg_changed, :vision, _id}, state) do
    handle_cast(:refresh_db_cfg, state)
  end

  def handle_info({ref, result}, state) when is_reference(ref) do
    case Map.fetch(state.inflight, ref) do
      {:ok, %{key: key, timer: timer}} ->
        Process.demonitor(ref, [:flush])
        Process.cancel_timer(timer)

        {:noreply,
         state
         |> put_in([:data, key], result)
         |> put_in([:data_at, key], DateTime.utc_now())
         |> update_in([:inflight], &Map.delete(&1, ref))}

      :error ->
        {:noreply, state}
    end
  end

  # A query that overran. Shut it down, and leave what it answered last time
  # where it is -- a board carrying times from two minutes ago is worth more
  # than one carrying none, and blanking a panel because a source hiccuped is
  # what this worker used to do.
  def handle_info({:query_overran, ref}, state) do
    case Map.fetch(state.inflight, ref) do
      {:ok, %{key: key, task: task}} ->
        Task.shutdown(task, :brutal_kill)

        Logger.warning(
          "Vision #{state.id}: #{inspect(key)} overran #{@query_timeout_ms}ms; keeping its last answer"
        )

        {:noreply, update_in(state, [:inflight], &Map.delete(&1, ref))}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.fetch(state.inflight, ref) do
      {:ok, %{key: key, timer: timer}} ->
        Process.cancel_timer(timer)

        if reason != :normal do
          Logger.warning(
            "Vision #{state.id}: #{inspect(key)} died (#{inspect(reason)}); keeping its last answer"
          )
        end

        {:noreply, update_in(state, [:inflight], &Map.delete(&1, ref))}

      :error ->
        {:noreply, state}
    end
  end

  # Trapped exits from the query tasks. The {:DOWN, ...} clause above is what
  # actually accounts for one ending; this only stops a task's exit from taking
  # the worker with it.
  def handle_info({:EXIT, _pid, _reason}, state) do
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
      # When each answer arrived, so a reader can say how old it is rather than
      # presenting a stale panel as though it were current.
      data_at: state.data_at,
      queries: state.vision_q,
      name: if(state.vision, do: state.vision.name, else: "Unknown")
    }
    {:reply, response, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  # Private helper to query all workers
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
