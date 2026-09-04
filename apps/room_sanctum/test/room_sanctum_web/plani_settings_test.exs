defmodule RoomSanctumWeb.PlaniSettingsTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Plani
  alias RoomSanctumWeb.PlaniLive.Show

  defp rows(plani), do: Show.settings(plani) |> Map.new(fn {l, k, v} -> {l, {k, v}} end)

  test "a blank bike limit says what blank means" do
    # "not set" would be true and useless: what it actually does is publish
    # everything inside the radius, which is the thing worth knowing.
    settings = rows(%Plani{radius: 800, limit: 5, bike_limit: nil})

    assert {:text, "all within the radius"} = settings["Bikes and docks per source"]
  end

  test "a set bike limit shows the number" do
    assert {:text, 12} = rows(%Plani{bike_limit: 12})["Bikes and docks per source"]
  end

  test "the flags are flags, so the template can draw them as flags" do
    settings = rows(%Plani{break_out: true, nearest_per_route: false})

    assert {:flag, true} = settings["One card per stop"]
    assert {:flag, false} = settings["One stop per line"]
  end

  test "the radius carries its unit" do
    assert {:text, "800 m"} = rows(%Plani{radius: 800})["Radius"]
  end

  test "nothing configured is nil rather than a made-up blank" do
    settings = rows(%Plani{})

    assert {:text, nil} = settings["Following tint"]
    assert {:text, nil} = settings["Home foci"]
    assert {:text, nil} = settings["Client"]
  end
end
