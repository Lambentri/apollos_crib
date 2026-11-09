defmodule RoomSanctumWeb.TintNestTest do
  @moduledoc """
  A query's tint with its offering's nested inside it.

  A query wears two colours that mean different things -- its own, and the one
  belonging to the offering it is asked of. Side by side they read as peers;
  one inside the other they read as what they are. The query is outer because
  the row is about the query.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.CoreComponents

  defp nest(opts), do: render_component(&tint_nest/1, opts)

  test "the query's badge holds its offering's" do
    html =
      nest(
        tint: "pink",
        label: "sfo",
        inner_tint: "gray",
        inner_label: "infra"
      )

    # Outer is the query's pink, inner the offering's gray, and the gray
    # badge opens after the pink one does.
    assert html =~ "border-pink-300"
    assert html =~ "border-gray-300"
    assert :binary.match(html, "border-pink-300") < :binary.match(html, "border-gray-300")

    assert html =~ ~r/bg-pink-100[^>]*>\s*sfo/
    assert html =~ ~r/bg-gray-100[^>]*>\s*infra/
  end

  test "an untinted offering leaves the query's badge alone" do
    html = nest(tint: "pink", label: "sfo")

    assert html =~ ~r/bg-pink-100[^>]*>\s*sfo/
    refute html =~ "gray"
  end

  test "an untinted query leaves the offering's badge standing on its own" do
    # Nothing of the query's own to nest inside, so the offering's badge
    # takes the place the pair would have had.
    html = nest(inner_tint: "gray", inner_label: "infra")

    assert html =~ ~r/bg-gray-100[^>]*>\s*infra/
    refute html =~ "pink"
  end

  test "neither tinted renders nothing" do
    assert nest([]) |> String.trim() == ""
  end

  test "subgroups are optional on either half" do
    html = nest(tint: "pink", inner_tint: "gray")

    # Two dots, one inside the other, and no word pill on either.
    assert html =~ "text-pink-500"
    assert html =~ "text-gray-500"
    refute html =~ "bg-pink-100"
    refute html =~ "bg-gray-100"
  end

  test "each half can carry its own click target" do
    # The list filters by colour, which is what the two stacked circles it
    # replaced used to do -- one event per colour.
    html =
      nest(
        tint: "pink",
        inner_tint: "gray",
        "phx-click": "set-tint",
        "phx-value-tint": "pink",
        inner_rest: %{"phx-click" => "set-tint", "phx-value-tint" => "gray"}
      )

    assert html =~ ~s(phx-value-tint="pink")
    assert html =~ ~s(phx-value-tint="gray")
  end

  test "an untinted query still gives the offering's badge its click target" do
    # The fallback branch hands the standing badge both the outer class and
    # the inner attributes, which are two ways of setting the same thing on
    # the same element -- worth pinning, since only one of them can win.
    html =
      nest(
        inner_tint: "gray",
        inner_label: "infra",
        class: "cursor-pointer",
        inner_rest: %{"phx-click" => "set-tint", "phx-value-tint" => "gray"}
      )

    assert html =~ ~r/bg-gray-100[^>]*>\s*infra/
    assert html =~ ~s(phx-value-tint="gray")
    assert html =~ "cursor-pointer"
  end
end
