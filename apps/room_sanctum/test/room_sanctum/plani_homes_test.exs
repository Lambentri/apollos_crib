defmodule RoomSanctum.PlaniHomesTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Plani
  alias RoomSanctum.Worker.Plani, as: Worker

  defp pt(lon, lat), do: %Geo.Point{coordinates: {lon, lat}, srid: 4326}

  defp house,
    do: %{id: 1, name: "House", tint: "sky", tint_label: "sleep", place: pt(-71.10, 42.39)}

  defp office,
    do: %{id: 2, name: "Office", tint: "sky", tint_label: "work", place: pt(-71.06, 42.36)}

  defp cabin,
    do: %{id: 3, name: "Cabin", tint: "amber", tint_label: nil, place: pt(-72.50, 43.10)}
  defp all, do: [house(), office(), cabin()]

  describe "which foci are home" do
    test "the first one, the named ones, then the tinted ones" do
      plani = %Plani{home_foci_id: 1, home_foci_ids: [3], home_tint: "sky"}

      # Order matters: home_foci_id stays the one a Plani with no position
      # falls back to.
      assert Plani.homes_for(plani, all()) == [1, 3, 2]
    end

    test "a Plani that names nothing extra keeps exactly its old single home" do
      assert Plani.homes_for(%Plani{home_foci_id: 1}, all()) == [1]
    end

    test "a tint alone is enough" do
      assert Plani.homes_for(%Plani{home_tint: "sky"}, all()) == [1, 2]
    end

    test "naming one that the tint also catches does not list it twice" do
      plani = %Plani{home_foci_id: 1, home_foci_ids: [2], home_tint: "sky"}

      assert Plani.homes_for(plani, all()) == [1, 2]
    end

    test "a tint narrowed to a subgroup takes only that corner of it" do
      # Both are sky; only one is where you sleep.
      assert Plani.homes_for(%Plani{home_tint: "sky", home_tint_labels: ["sleep"]}, all()) == [1]
      assert Plani.homes_for(%Plani{home_tint: "sky", home_tint_labels: ["work"]}, all()) == [2]
    end

    test "narrowing to several takes each of them" do
      plani = %Plani{home_tint: "sky", home_tint_labels: ["work", "sleep"]}

      assert Plani.homes_for(plani, all()) == [1, 2]
    end

    test "narrowing leaves behind what wears the tint with no subgroup" do
      unlabelled = %{id: 4, name: "Gym", tint: "sky", tint_label: nil, place: pt(-71.07, 42.37)}

      plani = %Plani{home_tint: "sky", home_tint_labels: ["sleep"]}

      assert Plani.homes_for(plani, all() ++ [unlabelled]) == [1]
    end

    test "a foci that predates labels is still caught by an unnarrowed follow" do
      # No :tint_label key at all, which is what a struct built before the
      # column existed looks like in a test fixture.
      old = %{id: 5, name: "Old", tint: "sky", place: pt(-71.08, 42.38)}

      assert Plani.homes_for(%Plani{home_tint: "sky"}, [old]) == [5]
    end
  end

  describe "which home it settles on" do
    test "the nearest to where the client last was" do
      assert Worker.nearest_home(all(), pt(-71.061, 42.361), 1) == office().place
      assert Worker.nearest_home(all(), pt(-71.101, 42.391), 1) == house().place
      assert Worker.nearest_home(all(), pt(-72.49, 43.09), 1) == cabin().place
    end

    test "with nothing ever heard, the first home" do
      # Which is where a Plani with one home has always gone.
      assert Worker.nearest_home(all(), nil, 2) == office().place
    end

    test "one home is that home, wherever the client was" do
      assert Worker.nearest_home([cabin()], pt(-71.10, 42.39), 1) == cabin().place
    end

    test "no homes at all is no anchor rather than a crash" do
      assert Worker.nearest_home([], nil, 1) == nil
    end

    test "a foci with no place cannot be the nearest to anything" do
      unplaced = %{id: 9, name: "Unplaced", tint: nil, place: nil}

      assert Worker.nearest_home([unplaced, house()], pt(-71.10, 42.39), 9) == house().place
    end
  end

  describe "the timeout" do
    test "only five minute steps are accepted" do
      for mins <- [5, 10, 15, 20, 25, 30] do
        changeset = Plani.changeset(%Plani{}, %{name: "P", home_foci_id: 1, home_after_mins: mins})
        refute changeset.errors[:home_after_mins]
      end
    end

    test "anything else is rejected" do
      # The form offers a menu, but a form is not the only way in.
      for mins <- [0, 3, 7, 45, -5] do
        changeset = Plani.changeset(%Plani{}, %{name: "P", home_foci_id: 1, home_after_mins: mins})
        assert changeset.errors[:home_after_mins]
      end
    end

    test "five minutes unless said otherwise" do
      assert %Plani{}.home_after_mins == 5
    end
  end
end
