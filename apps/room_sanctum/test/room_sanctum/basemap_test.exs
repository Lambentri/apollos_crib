defmodule RoomSanctum.BasemapTest do
  use ExUnit.Case, async: false

  alias RoomSanctum.Basemap

  setup do
    original = Application.get_env(:room_sanctum, :basemap, [])
    on_exit(fn -> Application.put_env(:room_sanctum, :basemap, original) end)
    :ok
  end

  defp configure(opts), do: Application.put_env(:room_sanctum, :basemap, opts)

  test "an unconfigured basemap renders no tags, leaving the frontend its default" do
    configure([])
    assert Basemap.meta_tags() == []
  end

  test "unset keys are dropped rather than emitted blank" do
    # A release sets only TILE_URL; System.get_env/1 returns nil for the rest,
    # and an empty meta tag would read to the frontend as \"draw nothing\".
    configure(url: "https://tiles.neiam.org/{z}/{x}/{y}.png", dark_url: nil, attribution: "  ")

    assert Basemap.meta_tags() == [{"url", "https://tiles.neiam.org/{z}/{x}/{y}.png"}]
  end

  test "every key reaches the frontend under its meta name" do
    configure(
      url: "https://tiles.example/light/{z}/{x}/{y}.png",
      dark_url: "https://tiles.example/dark/{z}/{x}/{y}.png",
      labels_url: "https://tiles.example/light-labels/{z}/{x}/{y}.png",
      dark_labels_url: "https://tiles.example/dark-labels/{z}/{x}/{y}.png",
      attribution: "&copy; someone",
      subdomains: "abcd",
      max_zoom: 18
    )

    assert Basemap.meta_tags() == [
             {"url", "https://tiles.example/light/{z}/{x}/{y}.png"},
             {"dark-url", "https://tiles.example/dark/{z}/{x}/{y}.png"},
             {"labels-url", "https://tiles.example/light-labels/{z}/{x}/{y}.png"},
             {"dark-labels-url", "https://tiles.example/dark-labels/{z}/{x}/{y}.png"},
             {"attribution", "&copy; someone"},
             {"subdomains", "abcd"},
             {"max-zoom", "18"}
           ]
  end

  test "TILE_MAX_ZOOM arrives from the environment as a string" do
    configure(url: "https://tiles.example/{z}/{x}/{y}.png", max_zoom: "18")

    assert {"max-zoom", "18"} in Basemap.meta_tags()
  end
end
