defmodule RoomGtfs.FeedHealth do
  @moduledoc """
  The last thing each realtime feed did, so prod is debuggable without a shell.

  ## Why this and not the logs

  The logs already say when a feed fails, and say it every thirty seconds
  forever. What they cannot answer is the question you actually have:

      which of my feeds are working right now, and since when

  Answering that from Loki means knowing every source's name, grepping for the
  absence of errors, and trusting that a feed nobody has logged about is
  healthy rather than silently not being polled at all. Two of the three real
  problems in this fleet were invisible that way: a source whose realtime URLs
  pointed at a `.proto` definition rather than a feed only showed up as a
  `:decode_failed` line that named a truncated URL, and a feed that had simply
  stopped being fetched would produce no log line whatsoever.

  So every fetch attempt records its outcome here, keyed by source and kind,
  and `RoomObservatory` turns that into metrics. A feed that stops being polled
  shows as a last-success age that climbs, which is the one symptom silence
  cannot produce.

  ## Shape

  An ETS table of `{{source_id, kind}, record}`, where kind is `:sa`, `:tu` or
  `:vp`. Written by the realtime workers, read by the metrics poller and the
  source page. Public and unsupervised on purpose -- see `ensure_table/0`: a
  missing table must never be the reason a poll fails.
  """

  @table :room_gtfs_feed_health

  @typedoc "sa = service alerts, tu = trip updates, vp = vehicle positions"
  @type kind :: :sa | :tu | :vp

  @doc """
  Note the outcome of one fetch.

  `result` is what the fetch returned. Success records the entity count so a
  feed that starts answering with nothing is distinguishable from one that has
  stopped answering; failure records the reason and leaves the previous success
  in place, because "failing now, last worked eleven minutes ago" is the useful
  reading and "failing now" alone is not.
  """
  def record(source_id, source_name, kind, url, result, duration_ms) do
    ensure_table()
    now = System.system_time(:second)
    previous = get(source_id, kind)

    record =
      case result do
        {:ok, feed} ->
          %{
            ok: true,
            entities: length(feed.entity),
            reason: nil,
            last_success_at: now,
            extensions: count_extensions(feed)
          }

        {:error, reason} ->
          %{
            ok: false,
            entities: previous[:entities],
            reason: describe(reason),
            last_success_at: previous[:last_success_at],
            extensions: previous[:extensions]
          }
      end

    record =
      Map.merge(record, %{
        source_id: source_id,
        source_name: source_name,
        kind: kind,
        url: url,
        last_attempt_at: now,
        duration_ms: duration_ms
      })

    :ets.insert(@table, {{source_id, kind}, record})
    record
  end

  @doc "One feed's last known state, or nil."
  def get(source_id, kind) do
    ensure_table()

    case :ets.lookup(@table, {source_id, kind}) do
      [{_key, record}] -> record
      [] -> nil
    end
  end

  @doc "Every feed's last known state, newest attempt first."
  def all do
    ensure_table()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, record} -> record end)
    |> Enum.sort_by(& &1.last_attempt_at, :desc)
  end

  @doc "Forget a source's feeds, for when one is deleted or reconfigured."
  def forget(source_id) do
    ensure_table()
    Enum.each([:sa, :tu, :vp], &:ets.delete(@table, {source_id, &1}))
  end

  # Created on first use rather than owned by a supervisor. The alternative is
  # another process in the tree whose only failure mode is taking realtime
  # polling down with it; a table that races two workers into creating it loses
  # one insert, once, at boot.
  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
        :ok

      _tid ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end

  # How many extension blobs the decoder could not name. Zero is the healthy
  # reading: it means every field in the feed has a definition behind it. A
  # number that appears after an agency changes its feed is the earliest
  # warning that we are dropping something.
  defp count_extensions(feed) do
    Enum.reduce(feed.entity, length(feed.header.__unknown_fields__), fn e, acc ->
      acc + length(e.__unknown_fields__) + unknown_in(e.trip_update) +
        unknown_in(e.vehicle) + unknown_in(e.alert)
    end)
  end

  defp unknown_in(nil), do: 0

  defp unknown_in(%{__unknown_fields__: fields} = message) do
    length(fields) + nested_unknown(message)
  end

  defp unknown_in(_other), do: 0

  defp nested_unknown(%{stop_time_update: updates}) when is_list(updates) do
    Enum.sum(Enum.map(updates, &length(&1.__unknown_fields__)))
  end

  defp nested_unknown(%{informed_entity: entities}) when is_list(entities) do
    Enum.sum(Enum.map(entities, &length(&1.__unknown_fields__)))
  end

  defp nested_unknown(_message), do: 0

  # Reasons reach metrics as a label, so they have to be a small closed set
  # rather than whatever an HTTP client happened to raise.
  defp describe(:bad_status), do: "bad_status"
  defp describe(:decode_failed), do: "decode_failed"
  defp describe(:not_protobuf), do: "not_protobuf"
  defp describe(%HTTPoison.Error{reason: reason}), do: "http_#{reason}"
  defp describe({:fetch_crashed, _reason}), do: "crashed"
  defp describe(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp describe(_reason), do: "unknown"
end
