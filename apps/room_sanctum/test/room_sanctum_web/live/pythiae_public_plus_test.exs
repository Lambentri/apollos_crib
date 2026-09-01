defmodule RoomSanctumWeb.PythiaePublicPlusTest do
  @moduledoc """
  The public board has two readings at two URLs: /p/p is Basic, /p/pl is Plus.

  A URL rather than a toggle, because a public board is something you point a
  screen at and walk away from -- which reading it shows has to survive the
  page being reloaded by nobody.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "pplus#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, vision} =
      Configuration.create_vision(%{name: "Commute", user_id: user.id, query_ids: []})

    {:ok, pythiae} =
      Configuration.create_pythiae(%{
        name: "hallway-#{System.unique_integer([:positive])}",
        user_id: user.id,
        ankyra: [],
        visions: [vision.id],
        curr_vision: vision.id
      })

    %{conn: conn, pythiae: pythiae}
  end

  test "both readings are public: no login for either", %{conn: conn, pythiae: pythiae} do
    assert {:ok, _live, _html} = live(conn, "/p/p/#{pythiae.name}")
    assert {:ok, _live, _html} = live(conn, "/p/pl/#{pythiae.name}")
  end

  test "each URL knows which reading it is", %{conn: conn, pythiae: pythiae} do
    {:ok, basic, _html} = live(conn, "/p/p/#{pythiae.name}")
    {:ok, plus, _html} = live(conn, "/p/pl/#{pythiae.name}")

    assert :show = :sys.get_state(basic.pid).socket.assigns.live_action
    assert :plus = :sys.get_state(plus.pid).socket.assigns.live_action
  end

  test "the plus board is titled as one", %{conn: conn, pythiae: pythiae} do
    {:ok, _live, html} = live(conn, "/p/pl/#{pythiae.name}")

    assert html =~ "Show Pythiae +"
  end

  test "both name the vision, for a screen someone walks past", %{
    conn: conn,
    pythiae: pythiae
  } do
    {:ok, _live, basic} = live(conn, "/p/p/#{pythiae.name}")
    {:ok, _live, plus} = live(conn, "/p/pl/#{pythiae.name}")

    assert basic =~ "VISION:"
    assert plus =~ "VISION:"
  end
end
