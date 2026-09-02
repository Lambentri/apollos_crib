defmodule RoomSanctum.QueryCache do
  @moduledoc """
  One answer per query, shared by everything that wants it.

  A query belongs to as many visions as care about it, and every vision asks
  for it separately on its own thirty second clock. In prod that is eighteen
  distinct queries being asked across six visions -- the same GTFS lookup, the
  one that takes ten seconds, run several times over for answers that would
  have been identical.

  Two things stop that here, and the second matters more than the first:

    * An answer is reused for `ttl` rather than fetched again.

    * While one caller is fetching, the others do not queue up behind it and do
      not start their own. They are told so, and go away. That is what stops a
      round of visions all missing the cache at the same instant and doing the
      work six times anyway, which a plain time-to-live cache would have
      allowed -- they tick together, so they miss together.

  Being told "someone else is on it" is a useful answer rather than a failure:
  the vision worker keeps the answer it already had, which is exactly what it
  does for a query that was slow or broken. A caller never waits.

  Kept in ETS rather than a GenServer for the same reason the realtime feeds
  are: this is read far more often than it is written, and a process holding it
  would serialise every reader behind whichever fetch is in progress -- which
  is the problem, not the solution.
  """

  require Logger

  @table :query_cache

  # A vision ticks every thirty seconds. Holding an answer for one tick means a
  # query runs at most once a round however many visions want it, and the board
  # is at most a tick behind where it would otherwise have been -- against
  # lookups that take ten seconds to produce, which is the trade being made.
  @default_ttl_ms 30_000

  # A claim that outlives this was abandoned by a caller that died mid-fetch.
  # Without an expiry the query would never be fetched again.
  @claim_ttl_ms 60_000

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
  A fresh answer for `key`, computing it only if nobody else is.

  Returns `{:ok, value}` with a cached or freshly computed answer, or `:busy`
  when another caller is already fetching this one -- in which case the caller
  should keep whatever it had rather than wait.
  """
  def fetch(key, fun, ttl_ms \\ @default_ttl_ms) do
    case lookup(key, ttl_ms) do
      {:ok, value} ->
        {:ok, value}

      :miss ->
        if claim(key) do
          try do
            value = fun.()
            put(key, value)
            {:ok, value}
          after
            release(key)
          end
        else
          :busy
        end
    end
  end

  @doc """
  The answer held for `key`, if it is younger than `ttl_ms`.
  """
  def lookup(key, ttl_ms \\ @default_ttl_ms) do
    with true <- exists?(),
         [{_k, value, at}] <- :ets.lookup(@table, {:answer, key}),
         true <- fresh?(at, ttl_ms) do
      {:ok, value}
    else
      _otherwise -> :miss
    end
  end

  @doc false
  def put(key, value) do
    if exists?(), do: :ets.insert(@table, {{:answer, key}, value, now()})
    :ok
  end

  @doc false
  def forget(key) do
    if exists?() do
      :ets.delete(@table, {:answer, key})
      :ets.delete(@table, {:claim, key})
    end

    :ok
  end

  # insert_new is the whole of the mutual exclusion: exactly one caller gets
  # true for a given key, and the rest are told to go away.
  defp claim(key) do
    cond do
      not exists?() ->
        # No table means no sharing, but the work still has to happen.
        true

      :ets.insert_new(@table, {{:claim, key}, now()}) ->
        true

      stale_claim?(key) ->
        # Whoever held this died without releasing it.
        Logger.warning("QueryCache: taking over an abandoned claim on #{inspect(key)}")
        :ets.insert(@table, {{:claim, key}, now()})
        true

      true ->
        false
    end
  end

  defp release(key) do
    if exists?(), do: :ets.delete(@table, {:claim, key})
    :ok
  end

  defp stale_claim?(key) do
    case :ets.lookup(@table, {:claim, key}) do
      [{_k, at}] -> not fresh?(at, @claim_ttl_ms)
      [] -> true
    end
  end

  defp fresh?(at, ttl_ms), do: now() - at < ttl_ms
  defp now, do: System.monotonic_time(:millisecond)

  @doc false
  def exists?, do: :ets.whereis(@table) != :undefined
end
