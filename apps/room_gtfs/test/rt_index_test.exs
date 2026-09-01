defmodule RoomGtfs.RTIndexTest do
  @moduledoc """
  Reading the realtime feeds out of a table instead of asking a worker for them.

  The worker that held these also fetches the feeds over HTTP, so every stop
  lookup queued behind those fetches and behind every other caller. Indexed by
  trip, because handing a reader the whole feed to find its sixteen trips would
  copy more than the call it replaced.
  """
  use ExUnit.Case, async: false

  alias RoomGtfs.RTIndex
  alias TransitRealtime, as: T

  setup do
    if :ets.whereis(RTIndex.table()) == :undefined do
      {:ok, _} = RTIndex.start_link()
      Process.sleep(20)
    end

    id = System.unique_integer([:positive])
    on_exit(fn -> :ets.match_delete(RTIndex.table(), {{id, :_, :_}, :_}) end)
    %{id: id}
  end

  defp entity(trip_id, stop_ids, attrs \\ []) do
    %T.FeedEntity{
      id: trip_id,
      trip_update: %T.TripUpdate{
        trip: struct(%T.TripDescriptor{trip_id: trip_id}, attrs),
        stop_time_update:
          Enum.map(stop_ids, fn s ->
            %T.TripUpdate.StopTimeUpdate{
              stop_id: s,
              arrival: %T.TripUpdate.StopTimeEvent{time: 123, delay: 60}
            }
          end)
      }
    }
  end

  describe "trip updates" do
    test "a source with nothing stored is a miss, not an empty answer", %{id: id} do
      # The distinction matters: a caller can fall back to the worker rather
      # than reporting that no trains are running.
      assert RTIndex.trip_updates(id, ["t1"], "s1") == :miss
    end

    test "a stored feed with no entities is an answer", %{id: id} do
      RTIndex.put_trip_updates(id, [])

      assert {:ok, []} = RTIndex.trip_updates(id, ["t1"], "s1")
    end

    test "only the trips asked for come back", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("t1", ["s1"]), entity("t2", ["s1"]), entity("t3", ["s1"])])

      assert {:ok, found} = RTIndex.trip_updates(id, ["t1", "t3"], "s1")
      assert Enum.map(found, & &1.trip_id) |> Enum.sort() == ["t1", "t3"]
    end

    test "the stop asked for is picked out of the trip's calls", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("t1", ["s1", "s2", "s3"])])

      assert {:ok, [tu]} = RTIndex.trip_updates(id, ["t1"], "s2")
      assert tu.stop.arrival.time == 123
    end

    test "a trip that does not call at the stop still answers, with no stop", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("t1", ["s1"])])

      assert {:ok, [tu]} = RTIndex.trip_updates(id, ["t1"], "elsewhere")
      assert tu.stop == nil
    end

    test "the trip's own relationship rides along", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("t1", ["s1"], schedule_relationship: :CANCELED)])

      assert {:ok, [tu]} = RTIndex.trip_updates(id, ["t1"], "s1")
      assert tu.schedule_relationship == :CANCELED
    end

    test "a later feed replaces the earlier one rather than adding to it", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("t1", ["s1"]), entity("gone", ["s1"])])
      RTIndex.put_trip_updates(id, [entity("t1", ["s1"])])

      assert {:ok, [_]} = RTIndex.trip_updates(id, ["t1", "gone"], "s1")
    end

    test "one source's feed is not another's", %{id: id} do
      other = System.unique_integer([:positive])
      RTIndex.put_trip_updates(id, [entity("t1", ["s1"])])

      assert RTIndex.trip_updates(other, ["t1"], "s1") == :miss
    end

    test "a stop update with no stop id is not indexed by one", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("t1", [nil, ""])])

      assert {:ok, [tu]} = RTIndex.trip_updates(id, ["t1"], "s1")
      assert tu.stops == %{}
    end
  end

  describe "suffix matching" do
    test "a feed naming the tail of a scheduled trip id still matches", %{id: id} do
      # NYCT: realtime "098600_5..S03R", schedule "ASP26GEN-1038-Sunday-00_098600_5..S03R"
      RTIndex.put_trip_updates(id, [entity("098600_5..S03R", ["s1"])])

      assert {:ok, [tu]} =
               RTIndex.trip_updates_by_suffix(
                 id,
                 ["ASP26GEN-1038-Sunday-00_098600_5..S03R"],
                 "s1"
               )

      assert tu.trip_id == "098600_5..S03R"
    end

    test "an unrelated trip does not match on a suffix", %{id: id} do
      RTIndex.put_trip_updates(id, [entity("something-else", ["s1"])])

      assert {:ok, []} = RTIndex.trip_updates_by_suffix(id, ["ASP26_098600"], "s1")
    end
  end

  describe "vehicles" do
    test "by trip, and all at once", %{id: id} do
      vehicles = [
        %{vehicle_id: "v1", trip_id: "t1", occupancy_status: :FULL},
        %{vehicle_id: "v2", trip_id: "t2", occupancy_status: :EMPTY}
      ]

      RTIndex.put_vehicles(id, vehicles)

      assert {:ok, [%{vehicle_id: "v1"}]} = RTIndex.vehicles(id, ["t1"])
      assert {:ok, both} = RTIndex.vehicles(id)
      assert length(both) == 2
    end

    test "a vehicle on no trip is still in the whole-feed answer", %{id: id} do
      RTIndex.put_vehicles(id, [%{vehicle_id: "v1", trip_id: nil}])

      assert {:ok, [_]} = RTIndex.vehicles(id)
      assert {:ok, []} = RTIndex.vehicles(id, ["t1"])
    end

    test "nothing stored is a miss", %{id: id} do
      assert RTIndex.vehicles(id) == :miss
      assert RTIndex.vehicles(id, ["t1"]) == :miss
    end
  end
end
