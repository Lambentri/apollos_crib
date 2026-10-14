defmodule RoomSanctum.GtfsFleetMarksTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias RoomSanctum.Configuration.Configs.GTFS

  defp change(attrs) do
    GTFS.changeset(%GTFS{}, Map.merge(%{"url" => "http://x/gtfs.zip", "tz" => "UTC"}, attrs))
  end

  test "the MBTA preset parses, a route list expanding to each route" do
    assert {:ok, marks} = GTFS.parse_fleet_marks(GTFS.mbta_new_trains_text())

    assert marks["Red"] == [[1900, 2151]]
    assert marks["Green-E"] == [[3900, 3923], [4001, 4102]]
    assert marks["749"] == [[1294, 1299]]
    assert map_size(marks) == 12
  end

  test "it reads back as the lines it went in as" do
    {:ok, marks} = GTFS.parse_fleet_marks(GTFS.mbta_new_trains_text())
    text = GTFS.fleet_marks_text(%{fleet_marks: marks})

    assert {:ok, ^marks} = GTFS.parse_fleet_marks(text)
    assert length(String.split(text, "\n")) == 4
  end

  test "a single car number is a range of one" do
    assert {:ok, %{"Red" => [[1901, 1901]]}} = GTFS.parse_fleet_marks("Red: 1901")
    assert GTFS.fleet_marks_text(%{fleet_marks: %{"Red" => [[1901, 1901]]}}) == "Red: 1901"
  end

  test "malformed lines are refused" do
    for line <- ["Red", "Red:", ": 1-2", "Red: 9-1", "Red: abc"] do
      assert {:error, ^line} = GTFS.parse_fleet_marks(line)
    end
  end

  test "the changeset stores the map, refuses a bad line, and leaves it alone when unmentioned" do
    assert %{"Red" => [[1, 2]]} =
             change(%{"fleet_marks_raw" => "Red: 1-2"}) |> Changeset.get_field(:fleet_marks)

    refute change(%{"fleet_marks_raw" => "nope"}).valid?

    existing = %GTFS{fleet_marks: %{"Red" => [[1, 2]]}}

    assert %{"Red" => [[1, 2]]} =
             GTFS.changeset(existing, %{"url" => "http://x", "tz" => "UTC"})
             |> Changeset.get_field(:fleet_marks)

    assert %{} ==
             GTFS.changeset(existing, %{"url" => "http://x", "tz" => "UTC", "fleet_marks_raw" => ""})
             |> Changeset.get_field(:fleet_marks)
  end
end
