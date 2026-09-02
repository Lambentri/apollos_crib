defmodule RoomSanctum.Worker.Vision do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus

  # Each query is asked on its own, so this is the cap on one of them rather
  # than on a round of them.
  #
  # Ten seconds was too tight and made things worse rather than safer. GTFS
  # arrival lookups against prod's data take on the order of ten seconds -- the
  # same slowness that used to blow the thirty second tick when a round asked
  # three of them one after another -- so a ten second cap turned "sometimes
  # completes" into "never completes", and every panel sat on its previous
  # answer for ever.
  #
  # Just under the tick instead: a query gets essentially the whole interval,
  # and the cap goes back to being a guard against a source that has genuinely
  # hung rather than a limit real work runs into. It is not a fix for the
  # slowness, which wants finding with an EXPLAIN against prod.
  @query_timeout_ms 25_000

  # How many of a vision's queries may be out at once.
  #
  # Asking them all together looked like the obvious way to stop waiting on the
  # slowest, and it emptied the database pool: six visions of seventeen queries
  # each, every thirty seconds, against fifteen connections. Nothing could get
  # one inside the ten second cap, so every query overran and every panel fell
  # back to its previous answer -- a board that had stopped updating entirely,
  # reported as thirteen hundred overruns in five minutes.
  #
  # Two at a time per vision, with the rest queued behind them. The answers
  # still land one by one, which is what made this worth doing; they simply do
  # not all leave at once.
  @max_inflight 2


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
       # ref => %{key:, task:, timer:} for the queries currently out, and the
       # ones waiting for a slot.
       inflight: %{},
       pending: []
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
    outstanding =
      state.inflight
      |> Map.values()
      |> Enum.map(& &1.key)
      |> Enum.concat(Enum.map(state.pending, &query_key/1))
      |> MapSet.new()

    # A query still out, or still queued, from the last round is not asked
    # again. That is the backpressure the brutal kill used to stand in for, and
    # unlike the kill it does not destroy work in progress.
    fresh = Enum.reject(state.vision_q, &MapSet.member?(outstanding, query_key(&1)))

    {:noreply, %{state | pending: state.pending ++ fresh} |> fill_slots()}
  end

  defp query_key(q), do: {q.id, q.source.type}

  defp fill_slots(state) do
    cond do
      map_size(state.inflight) >= @max_inflight -> state
      state.pending == [] -> state
      true -> state |> take_next() |> fill_slots()
    end
  end

  defp take_next(%{pending: [q | rest]} = state) do
    task = Task.async(fn -> query_cached(q) end)
    timer = Process.send_after(self(), {:query_overran, task.ref}, @query_timeout_ms)

    %{state | pending: rest}
    |> put_in([:inflight, task.ref], %{key: query_key(q), task: task, timer: timer})
  end

  # Handle async task completion
  # Told rather than asked: the same refresh, run when somebody edits the
  # vision instead of every four seconds in case they did.
  def handle_info({:cfg_changed, :vision, _id}, state) do
    handle_cast(:refresh_db_cfg, state)
  end

  def handle_info({ref, outcome}, state) when is_reference(ref) do
    case Map.fetch(state.inflight, ref) do
      {:ok, %{key: key, timer: timer}} ->
        Process.demonitor(ref, [:flush])
        Process.cancel_timer(timer)

        {:noreply,
         state
         |> record(key, outcome)
         |> update_in([:inflight], &Map.delete(&1, ref))
         |> fill_slots()}

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

        {:noreply, state |> update_in([:inflight], &Map.delete(&1, ref)) |> fill_slots()}

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

        {:noreply, state |> update_in([:inflight], &Map.delete(&1, ref)) |> fill_slots()}

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

  # Another vision was already fetching this one. Nothing arrived, so nothing
  # is written -- the panel keeps what it had, and picks up the shared answer
  # on the next round.
  defp record(state, _key, :skip), do: state

  defp record(state, key, {:ok, result}) do
    state
    |> put_in([:data, key], result)
    |> put_in([:data_at, key], DateTime.utc_now())
  end

  # Anything else is a task that did not return what this expects. Keeping the
  # previous answer is the same choice made everywhere else here, and is better
  # than a match error taking the worker down over one odd reply.
  defp record(state, key, other) do
    Logger.warning("Vision #{state.id}: #{inspect(key)} answered #{inspect(other)}; ignoring")
    state
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
  # Through the cache, so a query wanted by several visions is run once.
  #
  # `:busy` means another vision is fetching this very query right now. There
  # is nothing useful to do with that except carry on with the answer we
  # already have -- which is the same thing this worker does for a query that
  # was slow or broken, and is why waiting would be the wrong move.
  defp query_cached(q) do
    case RoomSanctum.QueryCache.fetch({q.id, q.source.type}, fn -> query_safely(q) end) do
      # query_safely already tags its own outcome, so this is {:ok, {:ok, _}}
      # or {:ok, :skip} -- the cache does not care which it is holding.
      {:ok, outcome} -> outcome
      :busy -> :skip
    end
  end

  # `:skip` rather than an empty list, and the difference matters.
  #
  # An empty list is a real answer -- nothing calls at this stop in the next
  # hour -- and writing it is correct. A query that raised has no answer at
  # all, and returning [] for it published "nothing is coming" on the strength
  # of a database timeout. The panel blanked, which is the very thing keeping
  # the last value was meant to prevent; it just arrived by a different route
  # than a task being killed.
  defp query_safely(q) do
    {:ok, query_one(q)}
  rescue
    e ->
      Logger.warning(
        "Query failed for #{inspect(q.source.type)} (#{q.source.id}): #{Exception.message(e)}"
      )

      :skip
  catch
    kind, reason ->
      Logger.warning(
        "Query #{kind} for #{inspect(q.source.type)} (#{q.source.id}): #{inspect(reason)}"
      )

      :skip
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
