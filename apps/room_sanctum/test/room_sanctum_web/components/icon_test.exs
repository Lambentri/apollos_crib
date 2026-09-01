defmodule RoomSanctumWeb.IconTest do
  @moduledoc """
  `<.icon>` draws Font Awesome, which is what this app loads.

  The generated version took heroicon names and rendered `<span
  class="hero-trash">`, which draws nothing without a heroicons dependency and
  a Tailwind plugin to turn the class into an SVG -- neither of which this app
  has. Every icon in the app was an empty span.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.CoreComponents

  defp render_icon(name, opts \\ []) do
    render_component(&icon/1, Keyword.merge([name: name], opts))
  end

  test "an icon carries the Font Awesome classes that draw it" do
    html = render_icon("fa-trash")

    assert html =~ "fa-solid"
    assert html =~ "fa-trash"
  end

  test "the caller's own classes are kept" do
    assert render_icon("fa-trash", class: "h-4 w-4 text-red-600") =~ "h-4 w-4 text-red-600"
  end

  test "no heroicon names are left in the app" do
    # They render nothing, silently, which is how they survived this long.
    heroicons =
      Path.wildcard("lib/**/*.{ex,heex}")
      |> Enum.filter(&(File.read!(&1) =~ ~s(name="hero-)))

    assert heroicons == []
  end
end
