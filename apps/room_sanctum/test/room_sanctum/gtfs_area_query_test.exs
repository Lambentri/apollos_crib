defmodule RoomSanctum.GtfsAreaQueryTest do
  @moduledoc """
  A GTFS query in either of its two modes.

  Station mode names one stop. Area mode names a foci and a radius, which is
  what lets the anchor move — the mode a Plani needs and the reason for the
  spatial index on stops.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Queries.GTFS

  defp changeset(params), do: GTFS.changeset(%GTFS{}, params)

  describe "station mode" do
    test "wants a stop" do
      assert changeset(%{mode: :station}).errors[:stop]
      assert changeset(%{mode: :station, stop: "1234"}).valid?
    end

    test "is what a query without a mode gets" do
      # Every GTFS query written before area mode existed has no mode in it,
      # and must go on meaning the stop it names.
      assert changeset(%{stop: "1234"}).valid?
    end
  end

  describe "area mode" do
    test "wants a foci and a radius, not a stop" do
      refute changeset(%{mode: :area}).valid?
      assert changeset(%{mode: :area, foci_id: 1, radius: 800}).valid?
    end

    test "refuses a radius that stops meaning near" do
      refute changeset(%{mode: :area, foci_id: 1, radius: 20}).valid?
      refute changeset(%{mode: :area, foci_id: 1, radius: 50_000}).valid?
    end

    test "refuses gathering from more stops than a board can show" do
      refute changeset(%{mode: :area, foci_id: 1, radius: 800, stops: 40}).valid?
      assert changeset(%{mode: :area, foci_id: 1, radius: 800, stops: 5}).valid?
    end

    test "has defaults worth having" do
      query = changeset(%{mode: :area, foci_id: 1}) |> Ecto.Changeset.apply_changes()

      assert query.radius == GTFS.default_radius()
      assert query.stops == GTFS.default_stops()
    end
  end
end
