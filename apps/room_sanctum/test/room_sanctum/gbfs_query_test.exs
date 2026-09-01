defmodule RoomSanctum.GbfsQueryTest do
  @moduledoc """
  A bike query asks one of two questions, and the form sends strings.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Queries.GBFS

  defp changeset(params), do: GBFS.changeset(%GBFS{}, params)

  test "a station query still only needs its station" do
    cs = changeset(%{"mode" => "station", "stop_id" => "s1"})

    assert cs.valid?
    assert Ecto.Changeset.apply_changes(cs).stop_id == "s1"
  end

  test "station is the default, so a query saved before area mode existed still reads" do
    assert %GBFS{mode: :station}= %GBFS{}
    assert changeset(%{"stop_id" => "s1"}).valid?
  end

  test "a station query with no station is rejected" do
    refute changeset(%{"mode" => "station"}).valid?
  end

  test "an area query needs somewhere to be and how far to look, not a station" do
    cs = changeset(%{"mode" => "area", "foci_id" => "3", "radius" => "750"})

    assert cs.valid?
    query = Ecto.Changeset.apply_changes(cs)
    assert query.foci_id == 3
    assert query.radius == 750
    # Off unless asked for: a dockless system has none, and on a system with
    # both it doubles the answer.
    refute query.include_docks
  end

  test "an area query can ask for the docks as well" do
    cs = changeset(%{"mode" => "area", "foci_id" => "3", "include_docks" => "true"})

    assert cs.valid?
    query = Ecto.Changeset.apply_changes(cs)
    assert query.include_docks
    assert query.radius == GBFS.default_radius()
  end

  test "an area query without a foci has nowhere to look" do
    refute changeset(%{"mode" => "area", "radius" => "500"}).valid?
  end

  test "a radius is bounded at both ends" do
    refute changeset(%{"mode" => "area", "foci_id" => "3", "radius" => "10"}).valid?
    refute changeset(%{"mode" => "area", "foci_id" => "3", "radius" => "50000"}).valid?
    assert changeset(%{"mode" => "area", "foci_id" => "3", "radius" => "5000"}).valid?
  end
end
