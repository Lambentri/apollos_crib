defmodule RoomSanctumWeb.AddVisionToPythiaeTest do
  @moduledoc """
  Putting a vision on a pythiae from the vision page -- the mirror of pinning a
  query to a vision from the query page.

  A pythiae holds a plain list of vision ids and a pointer at the one it is
  currently showing. The pointer is the part that goes wrong: a pythiae aimed
  at a vision it does not hold displays nothing at all.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "vtp#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, vision} = Configuration.create_vision(%{name: "Commute", user_id: user.id})

    %{conn: log_in_user(conn, user), user: user, vision: vision}
  end

  defp pythiae(user, name, visions \\ []) do
    {:ok, p} =
      Configuration.create_pythiae(%{
        name: "#{name}-#{System.unique_integer([:positive])}",
        user_id: user.id,
        ankyra: [],
        visions: visions,
        curr_vision: List.first(visions)
      })

    p
  end

  defp open(ctx) do
    {:ok, live, _html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :show, ctx.vision))
    send(live.pid, :update_sec)
    _ = render(live)
    live
  end

  describe "adding to an existing pythiae" do
    test "the vision lands on it, and it opens on that vision", ctx do
      p = pythiae(ctx.user, "hallway")

      live = open(ctx)
      render_click(live, "add-to-pythiae", %{"pythiae" => to_string(p.id)})

      p = Configuration.get_pythiae!(p.id)
      assert p.visions == [ctx.vision.id]
      # Nothing was current, so the vision it was given becomes what it shows.
      assert p.curr_vision == ctx.vision.id
    end

    test "a pythiae already showing something keeps showing it", ctx do
      {:ok, other} = Configuration.create_vision(%{name: "Evening", user_id: ctx.user.id})
      p = pythiae(ctx.user, "hallway", [other.id])

      live = open(ctx)
      render_click(live, "add-to-pythiae", %{"pythiae" => to_string(p.id)})

      p = Configuration.get_pythiae!(p.id)
      assert p.visions == [other.id, ctx.vision.id]
      assert p.curr_vision == other.id
    end

    test "adding one it already has does not add it twice", ctx do
      p = pythiae(ctx.user, "hallway", [ctx.vision.id])

      live = open(ctx)
      render_click(live, "add-to-pythiae", %{"pythiae" => to_string(p.id)})

      assert Configuration.get_pythiae!(p.id).visions == [ctx.vision.id]
    end
  end

  describe "making a pythiae for this vision" do
    test "the form is offered pre-filled with the vision's own name", ctx do
      live = open(ctx)
      html = render_click(live, "toggle-pythiae-sel", %{})

      assert html =~ ~s(name="pythiae[name]")
      assert html =~ ~s(value="Commute")
    end

    test "it is created around the vision and opens on it", ctx do
      live = open(ctx)
      render_click(live, "toggle-pythiae-sel", %{})
      render_submit(live, "add-to-new-pythiae", %{"pythiae" => %{"name" => "Commute"}})

      assert [p] = Configuration.get_pythiae(:vision, ctx.vision.id)
      assert p.name == "Commute"
      assert p.visions == [ctx.vision.id]
      assert p.curr_vision == ctx.vision.id
      assert p.ankyra == []
    end

    test "a nameless pythiae is not made", ctx do
      live = open(ctx)
      html = render_submit(live, "add-to-new-pythiae", %{"pythiae" => %{"name" => "   "}})

      assert html =~ "Give the pythiae a name"
      assert Configuration.get_pythiae(:vision, ctx.vision.id) == []
    end
  end

  describe "removing" do
    test "the vision comes off, and the pointer moves with it", ctx do
      {:ok, other} = Configuration.create_vision(%{name: "Evening", user_id: ctx.user.id})
      p = pythiae(ctx.user, "hallway", [ctx.vision.id, other.id])

      live = open(ctx)
      render_click(live, "remove-from-pythiae", %{"pythiae" => to_string(p.id)})

      p = Configuration.get_pythiae!(p.id)
      assert p.visions == [other.id]
      # It was showing the vision that just left, so it moves to what is left
      # rather than pointing at nothing.
      assert p.curr_vision == other.id
    end

    test "taking the last one off leaves nothing current", ctx do
      p = pythiae(ctx.user, "hallway", [ctx.vision.id])

      live = open(ctx)
      render_click(live, "remove-from-pythiae", %{"pythiae" => to_string(p.id)})

      p = Configuration.get_pythiae!(p.id)
      assert p.visions == []
      assert p.curr_vision == nil
    end
  end

  describe "the panel" do
    test "it offers the pythiae this vision is not on", ctx do
      on = pythiae(ctx.user, "on-it", [ctx.vision.id])
      off = pythiae(ctx.user, "not-on-it")

      live = open(ctx)
      html = render_click(live, "toggle-pythiae-sel", %{})

      assert html =~ off.name
      assert html =~ on.name
      assert html =~ "Add to"
    end

    test "somebody else's pythiae is not on offer", ctx do
      {:ok, stranger} =
        Accounts.register_user(%{
          email: "other#{System.unique_integer([:positive])}@example.com",
          password: "hello world!hello world!"
        })

      theirs = pythiae(stranger, "their-hallway")

      live = open(ctx)
      html = render_click(live, "toggle-pythiae-sel", %{})

      refute html =~ theirs.name
    end

    test "it opens even with no pythiae to add to: that is when you make one", ctx do
      live = open(ctx)
      html = render_click(live, "toggle-pythiae-sel", %{})

      refute html =~ "Add to"
      assert html =~ "Or a new one"
    end
  end
end
