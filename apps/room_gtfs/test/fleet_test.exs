defmodule RoomGtfs.FleetTest do
  use ExUnit.Case, async: true

  alias RoomGtfs.{Fleet, Worker}

  @mbta %{
    fleet_marks: %{
      "Red" => [[1900, 2151]],
      "Green-D" => [[3900, 3923], [4001, 4102]]
    }
  }

  defp arrival(route_id, attrs \\ []) do
    Map.merge(%{trip_id: "t1", trip: %{route_id: route_id}}, Map.new(attrs))
  end

  defp vehicle(attrs) do
    Map.merge(%{trip_id: "t1", label: nil, carriages: []}, Map.new(attrs))
  end

  test "one new car makes a new train" do
    v = vehicle(label: "1877-1910")

    assert %{marked: true} = Worker.merge_fleet_mark(arrival("Red"), @mbta, [v])
  end

  test "an old train is marked false, not left unsaid" do
    v = vehicle(label: "1500-1501")

    assert %{marked: false} = Worker.merge_fleet_mark(arrival("Red"), @mbta, [v])
  end

  test "carriage labels are preferred and each is marked" do
    v =
      vehicle(
        label: "1877",
        carriages: [%{label: "1877"}, %{label: "4010"}]
      )

    a =
      arrival("Green-D", carriages: [%{label: "1877"}, %{label: "4010"}])
      |> Worker.merge_fleet_mark(@mbta, [v])

    assert a.marked
    assert [%{marked: false}, %{marked: true}] = a.carriages
  end

  test "a route without rules, a source without rules, and no vehicle all say nothing" do
    v = vehicle(label: "1910")

    refute Map.has_key?(Worker.merge_fleet_mark(arrival("Blue"), @mbta, [v]), :marked)
    refute Map.has_key?(Worker.merge_fleet_mark(arrival("Red"), %{}, [v]), :marked)
    refute Map.has_key?(Worker.merge_fleet_mark(arrival("Red"), @mbta, []), :marked)
  end

  test "a label that is not a number matches nothing" do
    refute Fleet.car_marked?("19xx", [[1900, 2151]])
    refute Fleet.car_marked?(nil, [[1900, 2151]])
    assert Fleet.car_marked?(" 2151 ", [[1900, 2151]])
  end
end
