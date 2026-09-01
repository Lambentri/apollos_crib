defmodule RoomSanctumWeb.SourceLive.Work do
  @moduledoc """
  What the GTFS import queue is doing, across every source at once.

  The source page shows one feed's progress bar, which is the right view when
  you are looking at one feed. It is the wrong view for the question this
  answers: a queue with a concurrency of one, several feeds behind it, and no
  way to tell whether yours is running, waiting, or failed three times an hour
  ago without opening each source in turn.

  Two things are stitched together here, because neither is sufficient alone:

    * The Oban rows say what is queued, running, done or discarded, and are the
      only place a failure and its error text survive. They do not move on
      their own, so they are re-read on a timer.

    * The `"gtfs"` PubSub topic carries live progress for whichever import is
      running -- the same broadcasts the source page draws its bar from -- and
      arrives many times a second while a feed loads. Oban knows a job is
      executing; only this knows it is four files in.
  """
  use RoomSanctumWeb, :live_view_a

  import Ecto.Query

  alias RoomSanctum.{Configuration, Repo}

  # Oban rows change without telling anyone, so they are re-read. Slow enough
  # not to matter against a database this has spent the afternoon apologising
  # to, quick enough that a job finishing is noticed before you wonder.
  @reload_ms 3_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs")
      Process.send_after(self(), :reload, @reload_ms)
    end

    {:ok,
     socket
     |> assign(:page_title, "Import Queue")
     |> assign(:progress, %{})
     |> load()}
  end

  @impl true
  def handle_info(:reload, socket) do
    Process.send_after(self(), :reload, @reload_ms)
    {:noreply, load(socket)}
  end

  # Progress for one feed, as the source page reads it. Held per source rather
  # than as a single "current" bar: the queue runs one at a time today, and a
  # page that assumes that would quietly show the wrong feed's bar the day the
  # concurrency is raised.
  @impl true
  def handle_info({:gtfs, id, :done}, socket) do
    progress = Map.delete(socket.assigns.progress, to_string(id))

    {:noreply, socket |> assign(:progress, progress) |> load()}
  end

  @impl true
  def handle_info({:gtfs, _id, :disabled}, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:gtfs, id, file, complete, total}, socket) do
    # The "gtfs" topic carries every source in the installation, not just this
    # user's. Without this, somebody else's import shows up here as the thing
    # now running -- under a name this page cannot resolve, because it only
    # loaded its own feeds.
    if mine?(socket, id) do
      entry = %{step: file, value: percent(complete, total), at: DateTime.utc_now()}
      progress = Map.put(socket.assigns.progress, to_string(id), entry)

      {:noreply, assign(socket, :progress, progress)}
    else
      {:noreply, socket}
    end
  end


  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp mine?(socket, id) do
    case Integer.parse(to_string(id)) do
      {id, ""} -> Map.has_key?(socket.assigns.names, id)
      _otherwise -> false
    end
  end

  @impl true
  def handle_event("requeue", %{"id" => id}, socket) do
    case RoomGtfs.Worker.update_static_data(String.to_integer(id)) do
      {:ok, %{conflict?: true}} ->
        {:noreply, socket |> put_flash(:info, "That feed already has an import outstanding")}

      {:ok, _job} ->
        {:noreply, socket |> put_flash(:info, "Queued") |> load()}

      _otherwise ->
        {:noreply, put_flash(socket, :error, "Could not queue that import")}
    end
  end

  @doc """
  Give up on a job that is running and is not.

  Oban has no Lifeline plugin configured here, so nothing rescues a job whose
  process died -- a VM crash mid-import leaves the row in `executing` for good.
  That is not merely untidy: ImportJob's uniqueness covers `executing` with no
  expiry, so the stuck row blocks every future import of that feed, and the
  requeue button reports a conflict rather than doing anything.

  Cancelling moves it to a state uniqueness does not count, which is what frees
  the feed. It does not stop a genuinely running import -- if the process is
  alive it is asked to stop, which for a bulk load in progress means the next
  import starts from a truncate anyway.
  """
  @impl true
  def handle_event("clear", %{"id" => id}, socket) do
    case Oban.cancel_job(String.to_integer(id)) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Cleared. That feed can be queued again.")
         |> load()}

      _otherwise ->
        {:noreply, put_flash(socket, :error, "Could not clear that job")}
    end
  end

  @doc """
  How long a job has been executing, and whether that has stopped being
  plausible.

  An import of a large feed genuinely takes many minutes and can go a long
  while between broadcasts, so elapsed time alone is a weak signal and the
  threshold is deliberately generous. Past it, the honest thing is to say the
  job looks stranded and let someone who knows decide, rather than either
  hiding the button or quietly killing real work.
  """
  @stranded_after_s 3_600

  def stranded?(%{state: "executing"} = job, progress) do
    not reporting?(job, progress) and elapsed(job.attempted_at) > @stranded_after_s
  end

  def stranded?(_job, _progress), do: false

  # A job that has said something recently is alive whatever the clock says.
  defp reporting?(job, progress) do
    case source_id(job) do
      nil -> false
      id -> Map.has_key?(progress, to_string(id))
    end
  end

  defp elapsed(nil), do: 0
  defp elapsed(%NaiveDateTime{} = at), do: elapsed(DateTime.from_naive!(at, "Etc/UTC"))
  defp elapsed(%DateTime{} = at), do: DateTime.diff(DateTime.utc_now(), at)

  defp load(socket) do
    sources =
      Configuration.list_cfg_sources({:type, :gtfs})
      |> Enum.filter(&(&1.user_id == socket.assigns.current_user.id))

    names = Map.new(sources, &{&1.id, &1.name})

    socket
    |> assign(:sources, Enum.sort_by(sources, & &1.name))
    |> assign(:names, names)
    |> assign(:jobs, jobs())
  end

  # The queue's own history. Fifty is enough to cover a night's run of every
  # feed and its retries without turning the page into a log.
  defp jobs do
    from(j in "oban_jobs",
      where: j.queue == "gtfs_import",
      order_by: [desc: j.id],
      limit: 50,
      select: %{
        id: j.id,
        state: j.state,
        args: j.args,
        attempt: j.attempt,
        max_attempts: j.max_attempts,
        inserted_at: j.inserted_at,
        scheduled_at: j.scheduled_at,
        attempted_at: j.attempted_at,
        completed_at: j.completed_at,
        discarded_at: j.discarded_at,
        errors: j.errors
      }
    )
    |> Repo.all()
  rescue
    # The table is Oban's, not ours, and a page that cannot read it should say
    # so rather than take the whole view down.
    _ -> []
  end

  @doc """
  The import that is actually running, if one is.

  Both halves are needed and neither is sufficient. Oban says which job is
  executing, which is the authoritative answer to *which* feed -- but its rows
  are re-read on a timer, so it lags the start of an import by seconds. The
  progress broadcasts are immediate and say how far in it is, but arrive keyed
  by a source id with no name attached and keep arriving from a run that has
  since died.

  So: the freshest broadcast wins, because it is the one that moves; the
  executing job is the fallback for the moment after a job is picked up and
  before it has said anything.
  """
  def active(jobs, progress, names) do
    id =
      newest_progress(progress) ||
        Enum.find_value(jobs, fn job -> if job.state == "executing", do: source_id(job) end)

    case id do
      nil -> nil
      id -> %{source_id: id, name: Map.get(names, id), progress: Map.get(progress, to_string(id))}
    end
  end

  # An import that stopped saying anything a minute ago is not running; it is
  # a bar left behind by one that died, and leaving it up would be a page
  # confidently reporting work that is not happening.
  @stale_after_s 60

  defp newest_progress(progress) do
    progress
    |> Enum.reject(fn {_id, p} -> DateTime.diff(DateTime.utc_now(), p.at) > @stale_after_s end)
    |> Enum.max_by(fn {_id, p} -> DateTime.to_unix(p.at, :millisecond) end, fn -> nil end)
    |> case do
      {id, _p} -> String.to_integer(id)
      nil -> nil
    end
  end

  @doc """
  How long a feed has gone without importing, when that has become worth
  saying.

  Returns a bare number of days, or "N" for a feed that has never run, or nil
  while it is recent enough not to be interesting. Silent below the threshold
  on purpose: a badge on every feed all the time is a badge nobody reads, and
  the thing worth noticing is the one feed that has quietly stopped.

  A stale feed is not obviously broken from anywhere else in the app -- the
  board keeps showing yesterday's timetable, which looks like a timetable.
  """
  @stale_after_days 3

  def days_since_run(%{meta: %{last_run: %DateTime{} = at}}) do
    case DateTime.diff(DateTime.utc_now(), at, :day) do
      days when days > @stale_after_days -> days
      _recent -> nil
    end
  end

  def days_since_run(_source), do: "N"

  @doc false
  def source_id(%{args: %{"source_id" => id}}) when is_integer(id), do: id
  def source_id(%{args: %{"source_id" => id}}) when is_binary(id), do: String.to_integer(id)
  def source_id(_job), do: nil

  @doc """
  What a job's state should look like.

  Oban's vocabulary is not a reader's: `available` means waiting, `discarded`
  means it gave up. The colours follow the meaning rather than the word.
  """
  def state_label("available"), do: {"waiting", "badge-ghost"}
  def state_label("scheduled"), do: {"scheduled", "badge-ghost"}
  def state_label("executing"), do: {"running", "badge-info"}
  def state_label("retryable"), do: {"retrying", "badge-warning"}
  def state_label("completed"), do: {"done", "badge-success"}
  def state_label("discarded"), do: {"gave up", "badge-error"}
  def state_label("cancelled"), do: {"cancelled", "badge-ghost"}
  def state_label(other), do: {other, "badge-ghost"}

  @doc """
  The last error a job recorded, if it recorded one.

  Only the message: the stacktrace Oban keeps alongside it is worth having in
  the database and is not worth a table cell.
  """
  def last_error([_ | _] = errors) do
    errors
    |> List.last()
    |> Map.get("error", "")
    |> to_string()
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 160)
  end

  def last_error(_errors), do: nil

  @doc false
  def ago(nil), do: "--"

  def ago(%NaiveDateTime{} = at) do
    at |> DateTime.from_naive!("Etc/UTC") |> ago()
  end

  def ago(%DateTime{} = at) do
    case DateTime.diff(DateTime.utc_now(), at) do
      s when s < 60 -> "#{s}s ago"
      s when s < 3600 -> "#{div(s, 60)}m ago"
      s when s < 86_400 -> "#{div(s, 3600)}h ago"
      s -> "#{div(s, 86_400)}d ago"
    end
  end

  # The step names the worker broadcasts, said the way the source page says
  # them.
  @doc false
  def step_label(:downloading), do: "retrieving bundle"
  def step_label(:parsing), do: "parsing bundle"
  def step_label(:extracting), do: "extracting bundle"
  def step_label(:error), do: "error"
  def step_label(step), do: step |> to_string() |> String.replace("_", " ")

  defp percent(_complete, total) when total in [nil, 0], do: 0
  defp percent(complete, total), do: round(complete / total * 100)
end
