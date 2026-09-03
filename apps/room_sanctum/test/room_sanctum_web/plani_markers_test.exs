defmodule RoomSanctumWeb.PlaniMarkersTest do
  use ExUnit.Case, async: true

  alias RoomSanctumWeb.PlaniLive.Show

  # Spin's dockless SF feed, as it appeared in the trace of the 500.
  defp bike do
    %{
      kind: :bike,
      lat: 37.788274,
      lon: -122.40765170000002,
      name: "36ff0ff0-9b8f-4384-87f7-3e75fb43c158",
      source_id: 10,
      source_name: "Spin (SF)"
    }
  end

  defp stop do
    %{kind: :stop, lat: 42.39, lon: -71.11, name: "Davis", source_id: 4, source_name: "MBTA"}
  end

  test "a marker carries its location under both keys the map layers use" do
    # A station layer reads `place` and a free bike layer reads `point`. A
    # marker does not know which one it is bound for, and dot access on the
    # missing one raised rather than reading nil -- which was a 500, not a
    # missing pin.
    [marker] = Show.markers(%{places: [bike()]}, :bikes)

    assert %Geo.Point{coordinates: {-122.40765170000002, 37.788274}} = marker.point
    assert marker.point == marker.place
  end

  test "bikes and everything else land on their own layers" do
    where = %{places: [bike(), stop()]}

    assert [%{name: "36ff0ff0-9b8f-4384-87f7-3e75fb43c158"}] = Show.markers(where, :bikes)
    assert [%{name: "Davis"}] = Show.markers(where, :stations)
  end

  test "a Plani that has not ticked yet has no markers" do
    assert Show.markers(nil, :bikes) == []
    assert Show.markers(%{}, :stations) == []
  end
end
