defmodule RoomSanctumWeb.TintDotTest do
  @moduledoc """
  The dot marking a tinted source, query or vision. Every surface that shows a
  tint renders this, so it takes whatever a meta embed holds -- including a nil
  embed -- without the caller guarding first.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.CoreComponents

  test "renders the colour it is given" do
    html = render_component(&tint_dot/1, tint: "teal")

    assert html =~ "text-teal-500"
    assert html =~ "fa-circle"
  end

  test "renders nothing without a tint" do
    for tint <- [nil, ""] do
      assert render_component(&tint_dot/1, tint: tint) |> String.trim() == "",
             "rendered something for #{inspect(tint)}"
    end
  end

  test "takes extra classes for spacing" do
    assert render_component(&tint_dot/1, tint: "rose", class: "mr-2") =~ "mr-2"
  end

  test "a subgroup nests a badge inside a badge" do
    html = render_component(&tint_dot/1, tint: "teal", label: "transit")

    # The outer pill carries the tint and holds the dot; the inner one holds
    # the word. Both are in the tint, so the nesting reads as one thing.
    assert html =~ "border-teal-300"
    assert html =~ "bg-teal-50"
    assert html =~ "text-teal-500"
    assert html =~ ~r/bg-teal-100[^>]*>\s*transit/
  end

  test "a label without a tint shows nothing, dot or word" do
    # The label subdivides a colour, so with no colour under it there is
    # nothing for it to be a subdivision of.
    assert render_component(&tint_dot/1, tint: nil, label: "transit") |> String.trim() == ""
  end

  test "a dot with no label is still just a dot" do
    # No subgroup, no nesting: the badge would be an empty box around a dot.
    for label <- [nil, ""] do
      html = render_component(&tint_dot/1, tint: "teal", label: label)

      assert html =~ "text-teal-500"
      refute html =~ "text-xs"
      refute html =~ "border-teal-300"
      refute html =~ "bg-teal-50"
    end
  end

  test "every colour in the palette renders its own class" do
    for tint <- RoomSanctum.Tints.all() do
      assert render_component(&tint_dot/1, tint: tint) =~ "text-#{tint}-500"
    end
  end
end
