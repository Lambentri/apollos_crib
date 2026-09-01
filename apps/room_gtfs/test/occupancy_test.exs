defmodule RoomGtfs.OccupancyTest do
  use ExUnit.Case, async: true

  alias RoomGtfs.Worker

  defp vehicle(attrs \\ []) do
    Map.merge(
      %{trip_id: "t1", occupancy_status: :FULL, occupancy_percentage: 95, carriages: []},
      Map.new(attrs)
    )
  end

  test "the trip update's own word outranks the vehicle's" do
    stu = %{departure_occupancy_status: :MANY_SEATS_AVAILABLE}

    assert %{status: :MANY_SEATS_AVAILABLE} = Worker.occupancy_for(%{}, "t1", stu, [vehicle()])
  end

  test "falls back to the vehicle position, which is the one with a percentage" do
    stu = %{departure_occupancy_status: nil}

    assert %{status: :FULL, pct: 95} = Worker.occupancy_for(%{}, "t1", stu, [vehicle()])
  end

  test "a feed that said nothing gets nothing" do
    assert Worker.occupancy_for(%{}, "t1", nil, []) == nil
    assert Worker.occupancy_for(%{}, "t1", %{departure_occupancy_status: nil}, []) == nil
  end

  test "NO_DATA_AVAILABLE is declining to answer" do
    stu = %{departure_occupancy_status: :NO_DATA_AVAILABLE}

    assert Worker.occupancy_for(%{}, "t1", stu, []) == nil
  end

  test "NOT_ACCEPTING_PASSENGERS is an answer, and is kept" do
    stu = %{departure_occupancy_status: :NOT_ACCEPTING_PASSENGERS}

    assert %{status: :NOT_ACCEPTING_PASSENGERS} = Worker.occupancy_for(%{}, "t1", stu, [])
  end

  test "-1 is the protobuf default, not a percentage" do
    stu = %{departure_occupancy_status: nil}
    vehicles = [vehicle(occupancy_status: :STANDING_ROOM_ONLY, occupancy_percentage: -1)]

    assert %{status: :STANDING_ROOM_ONLY, pct: nil} = Worker.occupancy_for(%{}, "t1", stu, vehicles)
  end

  test "another trip's vehicle is not this trip's occupancy" do
    stu = %{departure_occupancy_status: nil}

    assert Worker.occupancy_for(%{}, "t2", stu, [vehicle(trip_id: "t1")]) == nil
  end

  describe "carriages" do
    defp carriage(seq, status, pct \\ -1) do
      %{
        id: "c#{seq}",
        label: "car #{seq}",
        sequence: seq,
        occupancy_status: status,
        occupancy_percentage: pct
      }
    end

    test "each carriage keeps its own occupancy, in coupling order" do
      vehicles = [
        vehicle(
          carriages: [
            carriage(3, :FULL),
            carriage(1, :EMPTY),
            carriage(2, :FEW_SEATS_AVAILABLE, 45)
          ]
        )
      ]

      assert %{carriages: carriages} =
               Worker.occupancy_for(%{}, "t1", %{departure_occupancy_status: nil}, vehicles)

      assert Enum.map(carriages, & &1.sequence) == [1, 2, 3]
      assert Enum.map(carriages, & &1.occupancy) == [:EMPTY, :FEW_SEATS_AVAILABLE, :FULL]
      assert Enum.map(carriages, & &1.occupancy_pct) == [nil, 45, nil]
    end

    test "a carriage the feed said nothing about stays in the train" do
      vehicles = [vehicle(carriages: [carriage(1, :EMPTY), carriage(2, :NO_DATA_AVAILABLE)])]

      assert %{carriages: [_, second]} =
               Worker.occupancy_for(%{}, "t1", %{departure_occupancy_status: nil}, vehicles)

      assert second.occupancy == nil
      assert second.sequence == 2
    end

    test "per-carriage detail alone is an answer, with no whole-train status" do
      vehicles = [vehicle(occupancy_status: nil, carriages: [carriage(1, :EMPTY)])]

      assert %{status: nil, carriages: [_]} =
               Worker.occupancy_for(%{}, "t1", %{departure_occupancy_status: nil}, vehicles)
    end

    test "a vehicle reporting no carriages reports no carriages" do
      assert %{carriages: []} =
               Worker.occupancy_for(%{}, "t1", %{departure_occupancy_status: nil}, [vehicle()])

      assert Worker.carriage_occupancy(nil) == []
    end
  end

  describe "schedule relationship" do
    defp merged(trip_rel, stop_rel) do
      Worker.merge_schedule_relationship(
        %{},
        %{trip: %{schedule_relationship: trip_rel}},
        %{schedule_relationship: stop_rel}
      )
    end

    test "as published is not news" do
      assert merged(:SCHEDULED, :SCHEDULED) == %{}
      assert merged(nil, nil) == %{}
    end

    test "a cancelled trip and a skipped stop stay apart" do
      assert %{trip_status: :CANCELED} = merged(:CANCELED, :SCHEDULED)
      assert %{stop_status: :SKIPPED} = merged(:SCHEDULED, :SKIPPED)
      assert Map.get(merged(:CANCELED, :SCHEDULED), :stop_status) == nil
    end

    test "an added trip says so" do
      assert %{trip_status: :ADDED} = merged(:ADDED, :SCHEDULED)
    end

    test "a value outside the enum is not a status" do
      assert merged(99, 99) == %{}
    end
  end

  describe "stop properties" do
    test "a track assignment and a headsign override are kept" do
      stu = %{
        stop_time_properties: %{assigned_stop_id: "127N", stop_headsign: "Uptown - short"}
      }

      assert %{assigned_stop_id: "127N", stop_headsign: "Uptown - short"} =
               Worker.merge_stop_properties(%{}, stu)
    end

    test "an empty string is not a track" do
      stu = %{stop_time_properties: %{assigned_stop_id: "", stop_headsign: nil}}

      assert Worker.merge_stop_properties(%{}, stu) == %{}
    end

    test "a stop time update carrying no properties, or none at all" do
      assert Worker.merge_stop_properties(%{}, %{stop_time_properties: nil}) == %{}
      assert Worker.merge_stop_properties(%{}, nil) == %{}
    end
  end

  test "a suffix-matching source finds its vehicle" do
    config = %{rt_trip_id_suffix: true}
    stu = %{departure_occupancy_status: nil}
    vehicles = [vehicle(trip_id: "098600_5..S03R")]

    assert %{status: :FULL} =
             Worker.occupancy_for(config, "ASP26GEN-1038-Sunday-00_098600_5..S03R", stu, vehicles)
  end
end
