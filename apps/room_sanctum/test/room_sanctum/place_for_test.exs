defmodule RoomSanctum.PlaceForTest do
  @moduledoc """
  Where a query is being asked from.

  Every source answered *at* a place resolved a foci the same two lines. A
  Plani asks the same questions from wherever its client is, which is not a
  foci and has no row to look up, so it hands the place over directly.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.Configuration

  setup do
    {:ok, user} =
      RoomSanctum.Accounts.register_user(%{
        email: "place#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home",
        place: %Geo.Point{coordinates: {-71.1, 42.4}, srid: 4326},
        user_id: user.id
      })

    %{foci: foci}
  end

  test "a query naming a foci is asked there", %{foci: foci} do
    assert %Geo.Point{coordinates: {-71.1, 42.4}} =
             Configuration.place_for!(%{foci_id: foci.id})

    assert Configuration.place_name(%{foci_id: foci.id}) == "Home"
  end

  test "a place handed over directly wins", %{foci: foci} do
    here = %Geo.Point{coordinates: {-0.1, 51.5}, srid: 4326}

    # Both present: the Plani's anchor is the one being asked about.
    assert Configuration.place_for!(%{place: here, foci_id: foci.id}) == here
  end

  test "an anchor that is not a foci says what it is" do
    here = %Geo.Point{coordinates: {-0.1, 51.5}, srid: 4326}

    # A board reading "Here" is telling the truth about an anchor that moves.
    assert Configuration.place_name(%{place: here}) == "Here"
  end

  test "a query with neither is not asked anywhere" do
    assert Configuration.place_for!(%{foci_id: nil}) == nil
    assert Configuration.place_for!(%{}) == nil
  end
end
