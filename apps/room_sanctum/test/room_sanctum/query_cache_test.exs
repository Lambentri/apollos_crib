defmodule RoomSanctum.QueryCacheTest do
  @moduledoc """
  One answer per query, shared by every vision that wants it.

  In prod, eighteen distinct queries were being asked across six visions on
  their own thirty second clocks -- the same ten second GTFS lookup run several
  times over for answers that would have been identical.

  A plain time-to-live cache would not have fixed that on its own: the visions
  tick together, so they miss together, and all six would still have done the
  work. Refusing the duplicate fetches is the part that matters.
  """
  use ExUnit.Case, async: false

  alias RoomSanctum.QueryCache

  setup do
    if :ets.whereis(QueryCache.table()) == :undefined do
      {:ok, _} = QueryCache.start_link()
      Process.sleep(20)
    end

    key = {System.unique_integer([:positive]), :gtfs}
    on_exit(fn -> QueryCache.forget(key) end)
    %{key: key}
  end

  describe "reuse" do
    test "the second caller gets the first one's answer without running", %{key: key} do
      me = self()

      ran = fn tag, value -> fn -> send(me, tag); value end end

      assert {:ok, [:answer]} = QueryCache.fetch(key, ran.(:ran, [:answer]))
      assert_received :ran

      assert {:ok, [:answer]} = QueryCache.fetch(key, ran.(:ran_again, [:nope]))
      refute_received :ran_again
    end

    test "an answer older than its ttl is fetched again", %{key: key} do
      {:ok, [:old]} = QueryCache.fetch(key, fn -> [:old] end, 20)
      Process.sleep(40)

      assert {:ok, [:new]} = QueryCache.fetch(key, fn -> [:new] end, 20)
    end

    test "one query's answer is not another's", %{key: key} do
      other = {System.unique_integer([:positive]), :gtfs}
      on_exit(fn -> QueryCache.forget(other) end)

      {:ok, [:a]} = QueryCache.fetch(key, fn -> [:a] end)

      assert {:ok, [:b]} = QueryCache.fetch(other, fn -> [:b] end)
    end

    test "lookup on its own does not compute anything", %{key: key} do
      assert QueryCache.lookup(key) == :miss

      QueryCache.put(key, [:stored])

      assert {:ok, [:stored]} = QueryCache.lookup(key)
    end
  end

  describe "while one caller is fetching" do
    test "the others are told, rather than queuing or duplicating", %{key: key} do
      me = self()

      slow =
        Task.async(fn ->
          QueryCache.fetch(key, fn ->
            send(me, :started)
            Process.sleep(300)
            [:answer]
          end)
        end)

      assert_receive :started, 500

      # Six visions ticking together must not become six fetches.
      assert QueryCache.fetch(key, fn -> flunk("should not have run") end) == :busy
      assert QueryCache.fetch(key, fn -> flunk("should not have run") end) == :busy

      assert {:ok, [:answer]} = Task.await(slow)
    end

    test "the claim is released once the answer lands", %{key: key} do
      {:ok, _} = QueryCache.fetch(key, fn -> [:answer] end)
      QueryCache.put(key, [:answer])

      # Not busy any more: expiring the answer lets the next caller fetch.
      assert {:ok, [:answer]} = QueryCache.fetch(key, fn -> [:other] end)
    end

    test "a caller that dies mid-fetch does not lock the query out for ever", %{key: key} do
      me = self()

      dead =
        spawn(fn ->
          QueryCache.fetch(key, fn ->
            send(me, :claimed)
            Process.sleep(:infinity)
          end)
        end)

      assert_receive :claimed, 500
      Process.exit(dead, :kill)

      # The claim outlives the process, which is why it carries an expiry.
      assert QueryCache.fetch(key, fn -> [:x] end) == :busy
      assert :ets.insert(QueryCache.table(), {{:claim, key}, System.monotonic_time(:millisecond) - 120_000})
      assert {:ok, [:recovered]} = QueryCache.fetch(key, fn -> [:recovered] end)
    end

    test "a raising fetch releases its claim" do
      key = {System.unique_integer([:positive]), :gtfs}
      on_exit(fn -> QueryCache.forget(key) end)

      assert_raise RuntimeError, fn -> QueryCache.fetch(key, fn -> raise "boom" end) end

      # The `after` is what makes the next caller able to try at all.
      assert {:ok, [:second]} = QueryCache.fetch(key, fn -> [:second] end)
    end
  end

  describe "without a table" do
    setup do
      if :ets.whereis(QueryCache.table()) != :undefined, do: :ets.delete(QueryCache.table())
      :ok
    end

    test "the work still happens, it is simply not shared", %{key: key} do
      assert {:ok, [:answer]} = QueryCache.fetch(key, fn -> [:answer] end)
      assert QueryCache.lookup(key) == :miss
    end
  end
end
