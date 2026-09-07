defmodule RoomGtfs.FeedCache do
  @moduledoc """
  Fetches each GTFS-realtime URL once, however many sources point at it.

  ## Why

  Realtime feeds are not always split the way static feeds are, and the MTA is
  the clearest case of both halves of that.

  Its bus static data is per borough -- `gtfs_b.zip`, `gtfs_m.zip` and so on --
  but there is a *single* citywide realtime feed at `gtfsrt.prod.obanyc.com`.
  Trip ids are one namespace across the city, so pointing every borough source
  at the same three URLs is correct, and each source filters realtime against
  its own static trips. Without this module it would also mean five sources
  fetching and parsing the same 400KB every thirty seconds.

  Its subway feeds go the other way: one URL carries trip updates *and* vehicle
  positions in the same FeedMessage, so `url_rt_tu` and `url_rt_vp` are the
  same value and a source fetched it twice per cycle all by itself.

  ## Single flight

  A plain "check the cache, fetch on a miss" would not help much. Every source
  runs its own poller on its own phase, so several of them can miss at the same
  instant and all start fetching. Concurrent callers for the same URL are
  therefore queued behind one fetch and all handed the same result.

  Hits are served straight out of ETS without troubling this process, so a
  cache hit costs a lookup rather than a GenServer round trip.

  ## Freshness

  `max_age` defaults to just under the RT poll interval. Longer and a poll
  would sometimes be handed the data it had already seen; much shorter and
  pollers on different phases stop sharing anything.

  ## What this does not do

  Workers still keep their own copy of the parsed feed in state, so several
  sources sharing a URL still hold several copies in memory -- what is saved is
  the fetching and the parsing, which was the expensive part. Reading from here
  at query time instead would fix that too, at the cost of reaching into how
  every realtime query works.

  Being unavailable is not an error. If this process is not running -- a bare
  iex session, a test, or an unlucky boot order, since room_zeus does not
  declare a dependency on this app -- callers fall through to fetching
  directly rather than failing a poll.
  """

  use GenServer

  require Logger

  @table :room_gtfs_feed_cache

  # {key, fetches, hits} -- positions named by @fetches/@hits below so a bump
  # cannot land in the wrong column.
  @counters {:__counters__, 0, 0}
  @fetches 2
  @hits 3

  # Pollers run on a 30s period (see RoomGtfs.Worker.RT.init/1). Just under it,
  # so each cycle refetches once and everything within the cycle shares.
  @default_max_age :timer.seconds(25)

  # Generous: a large feed on a slow link, behind another caller's fetch of the
  # same URL. The fetch itself is bounded by HTTPoison's own timeouts.
  @call_timeout :timer.seconds(90)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The parsed feed at `url`, fetching it only if nobody has within `max_age`.

  Returns what `RoomGtfs.Worker.RT.fetch_rt_url/2` returns, so it drops into
  call sites unchanged: `{:ok, %TransitRealtime.FeedMessage{}}` or
  `{:error, reason}`. Errors are not cached -- a feed that failed should be
  retried on the next poll, not remembered as broken for 25 seconds.

  `headers` are sent with the fetch; `scope` is who is asking, and entries are
  keyed by both the URL and it. A feed can require an API key, and two people
  reading the same feed hold different ones -- so the sharing this exists for
  stops at the owner's edge. Within one owner nothing changes: several sources
  pointing at one URL still fetch it once between them.

  Scoping by owner rather than by the headers themselves is deliberate. It
  keeps one entry per URL per person however their credentials are written,
  and it keeps secrets out of an ETS key that `stats/0` and any observer can
  read back.
  """
  def get(url, max_age \\ @default_max_age, headers \\ [], scope \\ nil)
      when is_binary(url) do
    key = {url, scope}

    case fresh_entry(key, max_age) do
      {:ok, _feed} = hit ->
        bump(@hits)
        hit

      :stale ->
        GenServer.call(__MODULE__, {:fetch, key, headers, max_age}, @call_timeout)
    end
  catch
    :exit, _reason ->
      RoomGtfs.Worker.RT.fetch_rt_url(url, headers)
  end

  @doc """
  Cached URLs, and how the traffic split -- `%{urls:, hits:, fetches:}`.

  `hits` far exceeding `fetches` is this module doing its job; the two being
  equal means nothing is actually shared.
  """
  def stats do
    case :ets.whereis(@table) do
      :undefined ->
        %{urls: 0, hits: 0, fetches: 0}

      _ ->
        [{_, fetches, hits}] = :ets.lookup(@table, :__counters__)
        %{urls: :ets.info(@table, :size) - 1, hits: hits, fetches: fetches}
    end
  end

  @impl true
  def init(_opts) do
    # Public and read_concurrency: every poller reads it directly, and only this
    # process writes.
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ets.insert(@table, @counters)
    {:ok, %{inflight: %{}, refs: %{}}}
  end

  @impl true
  def handle_call({:fetch, key, headers, max_age}, from, state) do
    # Re-checked: the caller missed, then waited on this mailbox, and another
    # fetch of the same key may have landed in between.
    case fresh_entry(key, max_age) do
      {:ok, _feed} = hit ->
        bump(@hits)
        {:reply, hit, state}

      :stale ->
        case state.inflight do
          %{^key => waiting} ->
            {:noreply, put_in(state.inflight[key], [from | waiting])}

          _ ->
            {_pid, ref} = spawn_fetch(key, headers)

            {:noreply,
             state
             |> put_in([:inflight, key], [from])
             |> put_in([:refs, ref], key)}
        end
    end
  end

  @impl true
  def handle_info({:fetched, key, result}, state) do
    {waiting, inflight} = Map.pop(state.inflight, key, [])

    # Dropped before the fetcher's :DOWN arrives, so the normal exit that
    # follows this message is not mistaken for a crash.
    {refs, _} = pop_ref(state.refs, key)

    case result do
      {:ok, _feed} ->
        :ets.insert(@table, {key, System.monotonic_time(:millisecond), result})
        bump(@fetches)

      {:error, _reason} ->
        # Deliberately not cached; see get/2.
        bump(@fetches)
    end

    # Everyone past the first was coalesced into this one fetch and never
    # touched the network, so they count as hits. Without this the counter
    # under-reports sharing exactly when sharing is working hardest -- several
    # sources asking for one URL at the same instant is the case single flight
    # exists for, and it was reading as zero hits.
    bump(@hits, length(waiting) - 1)

    Enum.each(waiting, &GenServer.reply(&1, result))
    {:noreply, %{state | inflight: inflight, refs: refs}}
  end

  # A fetcher that died without reporting. Everyone waiting on *that* URL would
  # otherwise sit here until their call timeout. The ref is how the right URL is
  # identified; a fetcher that already sent its result is no longer in refs, so
  # its ordinary exit falls through.
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.refs, ref) do
      {nil, _refs} ->
        {:noreply, state}

      {{url, _scope} = key, refs} ->
        Logger.warning("gtfs-rt fetch of #{url} died: #{inspect(reason)}")
        {waiting, inflight} = Map.pop(state.inflight, key, [])
        Enum.each(waiting, &GenServer.reply(&1, {:error, {:fetch_crashed, reason}}))
        {:noreply, %{state | inflight: inflight, refs: refs}}
    end
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp pop_ref(refs, key) do
    case Enum.find(refs, fn {_ref, k} -> k == key end) do
      nil -> {refs, nil}
      {ref, _} -> {Map.delete(refs, ref), ref}
    end
  end

  defp spawn_fetch({url, _scope} = key, headers) do
    parent = self()

    spawn_monitor(fn ->
      result =
        try do
          RoomGtfs.Worker.RT.fetch_rt_url(url, headers)
        rescue
          e -> {:error, e}
        catch
          kind, reason -> {:error, {kind, reason}}
        end

      send(parent, {:fetched, key, result})
    end)
  end

  defp fresh_entry(key, max_age) do
    with [{^key, at, result}] <- safe_lookup(key),
         true <- System.monotonic_time(:millisecond) - at <= max_age do
      result
    else
      _ -> :stale
    end
  end

  defp safe_lookup(key) do
    :ets.lookup(@table, key)
  rescue
    ArgumentError -> []
  end

  defp bump(pos, by \\ 1)

  defp bump(_pos, by) when by <= 0, do: 0

  defp bump(pos, by) do
    :ets.update_counter(@table, :__counters__, {pos, by})
  rescue
    ArgumentError -> 0
  end
end
