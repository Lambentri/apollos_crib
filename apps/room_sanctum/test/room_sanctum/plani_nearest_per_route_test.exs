defmodule RoomSanctum.PlaniNearestPerRouteTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Worker.Plani

  defp arrival(route, direction, time) do
    %{arrival_time: time, trip: %{route_id: route, direction: %{direction: direction}}}
  end

  # Nearest first, the order `nearby_stops/4` returns.
  defp by_stop do
    [
      {%{stop_id: "a", stop_name: "Nearest"},
       [arrival("87", "In", "08:00"), arrival("87", "In", "08:12")]},
      {%{stop_id: "b", stop_name: "Across the street"},
       [arrival("87", "Out", "08:03"), arrival("87", "In", "08:01")]},
      {%{stop_id: "c", stop_name: "Furthest"},
       [arrival("87", "In", "08:02"), arrival("96", "In", "08:30")]}
    ]
  end

  test "a line is kept only at the nearest stop that has it" do
    [_, _, {_, furthest}] = Plani.nearest_per_route(by_stop(), %{nearest_per_route: true})

    # The 87 belongs to the nearest stop; the 96 stops nowhere nearer.
    assert Enum.map(furthest, & &1.trip.route_id) == ["96"]
  end

  test "the winning stop keeps every departure of that line, not just the first" do
    # Claiming per arrival rather than per stop would leave one time here,
    # which is the wrong half of the point -- a board is worth reading because
    # it shows the next two.
    [{_, nearest} | _] = Plani.nearest_per_route(by_stop(), %{nearest_per_route: true})

    assert Enum.map(nearest, & &1.arrival_time) == ["08:00", "08:12"]
  end

  test "the other side of the street is a different departure and survives" do
    [_, {_, across}, _] = Plani.nearest_per_route(by_stop(), %{nearest_per_route: true})

    assert Enum.map(across, & &1.trip.direction.direction) == ["Out"]
  end

  test "a feed that names no direction groups rather than raising" do
    stops = [
      {%{stop_id: "a"}, [%{arrival_time: "08:00", trip: %{route_id: "87", direction: nil}}]},
      {%{stop_id: "b"}, [%{arrival_time: "08:05", trip: %{route_id: "87", direction: nil}}]}
    ]

    assert [{_, [_]}, {_, []}] = Plani.nearest_per_route(stops, %{nearest_per_route: true})
  end

  test "off, it changes nothing" do
    assert Plani.nearest_per_route(by_stop(), %{nearest_per_route: false}) == by_stop()
  end
end
