defmodule RoomSanctumWeb.PythiaePublicMapTest do
  @moduledoc """
  The public map view: a pythiae's current vision drawn where its queries are,
  on a page with nothing else on it.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "pmap#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, vision} = Configuration.create_vision(%{name: "Commute", user_id: user.id, query_ids: []})

    {:ok, pythiae} =
      Configuration.create_pythiae(%{
        name: "hallway-#{System.unique_integer([:positive])}",
        user_id: user.id,
        ankyra: [],
        visions: [vision.id],
        curr_vision: vision.id
      })

    %{conn: conn, user: user, pythiae: pythiae, vision: vision}
  end

  test "the map is public: no login, and it is the whole page", %{conn: conn, pythiae: pythiae} do
    {:ok, _live, html} = live(conn, "/p/m/#{pythiae.name}")

    assert html =~ ~s(id="pythiae-map")
    # Sized to the window rather than to a card, and without the gutter the
    # in-page map carries.
    assert html =~ "100dvh"
    refute html =~ "mt-4 relative"
  end

  test "the map gets the window, not a centred column", %{conn: conn, pythiae: pythiae} do
    {:ok, _live, html} = live(conn, "/p/m/#{pythiae.name}")

    # The :live layout wraps every other page in `container mx-auto`, which is
    # a max-width: the map rendered as a boxed column with the window showing
    # either side of it.
    refute html =~ "container mx-auto"
  end

  test "it names the pythiae, for a screen someone walks past", %{conn: conn, pythiae: pythiae} do
    {:ok, _live, html} = live(conn, "/p/m/#{pythiae.name}")

    assert html =~ pythiae.name
  end

  test "the legend is off: the page is the map", %{conn: conn, pythiae: pythiae} do
    {:ok, _live, html} = live(conn, "/p/m/#{pythiae.name}")

    refute html =~ "Map Legend"
  end

  test "it draws before the vision worker has said anything", %{conn: conn, pythiae: pythiae} do
    # The worker is not running in tests, and the first refresh is 500ms out --
    # the page has to be worth looking at in the meantime rather than crashing
    # or rendering blank.
    {:ok, _live, html} = live(conn, "/p/m/#{pythiae.name}")

    assert html =~ "<leaflet-map"
  end

  test "a mistyped name is a 404, not a crash", %{conn: conn} do
    # A public URL someone will type by hand, and get_pythiae!/2 answers with
    # nil rather than raising, which used to reach the template as nil.name.
    assert_error_sent 404, fn -> live(conn, "/p/m/no-such-pythiae") end
  end
end
