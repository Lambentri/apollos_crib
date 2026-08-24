defmodule RoomGtfs.ImportJob do
  @moduledoc """
  The queue in front of GTFS static imports.

  ## What this fixes

  A static import downloads a feed and COPYs eight files into Postgres. For a
  large agency that is a couple of million `gtfs_stop_times` rows, preceded by
  a delete of the couple of million already there. One at a time, that is a
  slow but unremarkable bulk load.

  The trouble was that nothing said "one at a time". Every GTFS source runs its
  own worker with its own scheduler, and every one of those schedulers checks
  at the same instant — `Periodic` firing on `%Time{hour: 0, minute: 0}` — so
  every feed that happened to be due began importing together. Four concurrent
  bulk loads against the same eight tables is what made Postgres miserable.

  Pool size was never a brake on this, which is worth knowing before assuming
  it was: `write_file/4` opens its own `Postgrex` connection per file rather
  than checking one out of the Ecto pool, so `pool_size` bounded none of it.

  The scheduling has not moved. Each worker still decides *whether* its feed is
  due, on its own `run_period` and `last_run`. This decides *when* the import
  it asked for actually runs, and the answer is "when the one before it has
  finished" — the `gtfs_import` queue is configured with a concurrency of 1 in
  `config/config.exs`, and that single number is the entire mechanism. Raising
  it is how you trade Postgres load for getting through the feeds faster.

  ## One import per source

  Uniqueness covers everything not yet finished — queued, scheduled, running,
  waiting to retry — so a source can have at most one import outstanding.
  Without it the midnight check firing twice inside its minute, or someone
  pressing the button on the source page while the nightly run is still
  queued, would enqueue a second import of a feed whose tables the first one is
  midway through filling. Both would then truncate and reload the same rows.

  Completed jobs do not block anything, so tomorrow's run enqueues normally.

  ## Where to watch it

  The `gtfs_import` queue reports through the same PromEx Oban plugin as every
  other queue, so the Background jobs row of the apollos-crib dashboard picks
  it up with no change — queue depth there is how long the feeds are waiting.
  Per-feed progress still broadcasts on the `"gtfs"` PubSub topic exactly as
  before; moving the work into a job process did not change that.
  """

  use Oban.Worker,
    queue: :gtfs_import,
    max_attempts: 3,
    unique: [
      keys: [:source_id],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]

  require Logger

  @doc """
  Queue a static import for a source.

  Returns `{:ok, job}` whether or not it actually enqueued anything: a job that
  collides with one already outstanding for the same source comes back with
  `conflict?: true` rather than as an error, so callers do not have to care
  which it was.
  """
  def enqueue(source_id) do
    id = normalize_id(source_id)

    with {:ok, job} <- Oban.insert(new(%{source_id: id})) do
      # Tell the source page something happened. Pressing update used to start
      # the download immediately, so the progress bar moved within a second or
      # two; now the import may sit behind another feed for a while, and with
      # nothing broadcast until it starts the button looks broken.
      if not job.conflict? do
        Phoenix.PubSub.broadcast(
          RoomSanctum.PubSub,
          "gtfs",
          {:gtfs, Integer.to_string(id), :queued, 0, 10}
        )
      end

      {:ok, job}
    end
  end

  # Callers arrive with two different shapes: the scheduler holds the worker's
  # registry name, which is the source id as a string, while the source page
  # hands over an integer parsed from the URL. Normalising matters more than it
  # looks — uniqueness compares args, and `%{source_id: 1}` and
  # `%{source_id: "1"}` are different args, so the two paths would not see each
  # other and both would enqueue.
  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)

  @impl Oban.Worker
  # A large feed genuinely takes tens of minutes. The default is no timeout at
  # all, which at a concurrency of 1 means a wedged download holds the only
  # slot indefinitely and no other feed imports again until the node restarts.
  def timeout(_job), do: :timer.minutes(45)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"source_id" => id}}) do
    RoomGtfs.Worker.Static.import_static(id)
  rescue
    Ecto.NoResultsError ->
      # Deleted between enqueue and execution. Retrying cannot bring it back,
      # so stop now rather than failing twice more first.
      Logger.info("GTFS::#{id} static import cancelled, source no longer exists")
      {:cancel, "source #{id} no longer exists"}
  end
end
