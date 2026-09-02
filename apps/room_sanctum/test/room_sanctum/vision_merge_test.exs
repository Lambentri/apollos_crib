defmodule RoomSanctum.VisionMergeTest do
  @moduledoc """
  A vision's answers land one at a time, and a source that fails keeps the one
  it gave last.

  Both of those were wrong in the same place. The worker replaced its whole
  data map when a single task finished, so nothing on the board moved until the
  slowest source had answered -- and a query that failed contributed an empty
  list, which overwrote a perfectly good answer from thirty seconds earlier. A
  source that hiccupped once blanked its panel.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Worker.Vision

  @key {1, :gtfs}
  @other {2, :tidal}

  defp state(attrs \\ %{}) do
    Map.merge(
      %{id: "9", vision: nil, vision_q: [], data: %{}, data_at: %{}, inflight: %{}},
      attrs
    )
  end

  defp outstanding(key) do
    ref = make_ref()
    timer = Process.send_after(self(), :never, 60_000)
    task = Task.async(fn -> Process.sleep(60_000) end)

    {ref, %{key: key, task: task, timer: timer}}
  end

  describe "an answer arriving" do
    test "merges into data and stamps when it arrived" do
      {ref, entry} = outstanding(@key)
      before = DateTime.utc_now()

      {:noreply, s} = Vision.handle_info({ref, [:arrival]}, state(%{inflight: %{ref => entry}}))

      assert s.data[@key] == [:arrival]
      assert DateTime.compare(s.data_at[@key], before) != :lt
      assert s.inflight == %{}
    end

    test "leaves the other panels alone" do
      {ref, entry} = outstanding(@key)

      existing = %{@other => [:tide]}
      at = %{@other => ~U[2026-09-01 00:00:00Z]}

      {:noreply, s} =
        Vision.handle_info(
          {ref, [:arrival]},
          state(%{data: existing, data_at: at, inflight: %{ref => entry}})
        )

      # The whole map used to be replaced, so a source still out lost its data.
      assert s.data[@other] == [:tide]
      assert s.data_at[@other] == ~U[2026-09-01 00:00:00Z]
      assert s.data[@key] == [:arrival]
    end

    test "an answer nobody is waiting for is ignored" do
      {:noreply, s} = Vision.handle_info({make_ref(), [:stray]}, state())

      assert s.data == %{}
    end
  end

  describe "a query that fails" do
    test "overrunning keeps the answer it gave last" do
      {ref, entry} = outstanding(@key)

      s0 =
        state(%{
          data: %{@key => [:yesterday]},
          data_at: %{@key => ~U[2026-09-01 00:00:00Z]},
          inflight: %{ref => entry}
        })

      {:noreply, s} = Vision.handle_info({:query_overran, ref}, s0)

      # A board carrying times from two minutes ago beats one carrying none.
      assert s.data[@key] == [:yesterday]
      assert s.data_at[@key] == ~U[2026-09-01 00:00:00Z]
      assert s.inflight == %{}
    end

    test "dying keeps it too" do
      {ref, entry} = outstanding(@key)

      s0 = state(%{data: %{@key => [:yesterday]}, inflight: %{ref => entry}})

      {:noreply, s} = Vision.handle_info({:DOWN, ref, :process, self(), :killed}, s0)

      assert s.data[@key] == [:yesterday]
      assert s.inflight == %{}
    end

    test "a normal exit is not reported as a failure" do
      {ref, entry} = outstanding(@key)

      {:noreply, s} =
        Vision.handle_info({:DOWN, ref, :process, self(), :normal}, state(%{inflight: %{ref => entry}}))

      assert s.inflight == %{}
    end

    test "a DOWN for something else does not disturb the round" do
      {ref, entry} = outstanding(@key)
      s0 = state(%{inflight: %{ref => entry}})

      {:noreply, s} = Vision.handle_info({:DOWN, make_ref(), :process, self(), :killed}, s0)

      assert Map.has_key?(s.inflight, ref)
    end
  end

  describe "state given out" do
    test "carries when each answer arrived" do
      at = %{@key => ~U[2026-09-01 12:00:00Z]}

      {:reply, reply, _s} =
        Vision.handle_call(:return_state, self(), state(%{data: %{@key => [:a]}, data_at: at}))

      assert reply.data_at[@key] == ~U[2026-09-01 12:00:00Z]
      # The existing shape is untouched; every reader matches on part of it.
      assert reply.data[@key] == [:a]
      assert Map.has_key?(reply, :queries)
      assert Map.has_key?(reply, :name)
    end
  end
end
