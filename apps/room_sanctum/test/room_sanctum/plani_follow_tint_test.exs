defmodule RoomSanctum.PlaniFollowTintTest do
  @moduledoc """
  Which sources a Plani asks when it follows a colour.

  A tint runs out as a grouping once a colour means "everything about getting
  to work" and half of that is buses and half is bikes; the subgroup label is
  what splits it without spending a second colour. Following one narrowed to
  some of its subgroups has to keep meaning the same thing as before for every
  Plani that names none.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Plani

  defp source(id, tint, label), do: %{id: id, meta: %{tint: tint, tint_label: label}}

  defp bus, do: source(1, "sky", "transit")
  defp train, do: source(2, "sky", "transit")
  defp bikes, do: source(3, "sky", "wheels")
  defp plain, do: source(4, "sky", nil)
  defp weather, do: source(5, "amber", "transit")
  defp untinted, do: %{id: 6, meta: nil}

  defp all, do: [bus(), train(), bikes(), plain(), weather(), untinted()]

  test "an unnarrowed follow takes the whole colour, as it always has" do
    plani = %Plani{sources: [], follow_tint: "sky"}

    assert Plani.sources_for(plani, all()) == [1, 2, 3, 4]
  end

  test "narrowing to a subgroup takes only that subgroup" do
    plani = %Plani{sources: [], follow_tint: "sky", follow_tint_labels: ["transit"]}

    # Not the bikes, not the untinted one, and not the amber source that
    # happens to wear the same word.
    assert Plani.sources_for(plani, all()) == [1, 2]
  end

  test "narrowing to several takes each of them" do
    plani = %Plani{sources: [], follow_tint: "sky", follow_tint_labels: ["transit", "wheels"]}

    assert Plani.sources_for(plani, all()) == [1, 2, 3]
  end

  test "a narrowed follow leaves the unlabelled ones wearing the tint behind" do
    plani = %Plani{sources: [], follow_tint: "sky", follow_tint_labels: ["wheels"]}

    refute 4 in Plani.sources_for(plani, all())
  end

  test "naming a source still adds it regardless of the narrowing" do
    # The union is the point: a follow is a shortcut to most of a list, with
    # one or two named on top.
    plani = %Plani{sources: [4], follow_tint: "sky", follow_tint_labels: ["transit"]}

    assert Plani.sources_for(plani, all()) == [4, 1, 2]
  end

  test "narrowing with no tint to narrow follows nothing" do
    plani = %Plani{sources: [], follow_tint: nil, follow_tint_labels: ["transit"]}

    assert Plani.sources_for(plani, all()) == []
  end

  test "a source tinted but never labelled is caught by an unnarrowed follow" do
    # Every source in the database on the day labels shipped.
    plani = %Plani{sources: [], follow_tint: "sky"}

    assert Plani.sources_for(plani, [%{id: 9, meta: %{tint: "sky"}}]) == [9]
  end
end
