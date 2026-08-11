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

  test "every colour in the palette renders its own class" do
    for tint <- RoomSanctum.Tints.all() do
      assert render_component(&tint_dot/1, tint: tint) =~ "text-#{tint}-500"
    end
  end
end
