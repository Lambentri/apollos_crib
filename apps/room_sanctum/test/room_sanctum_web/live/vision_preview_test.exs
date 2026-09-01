defmodule RoomSanctumWeb.VisionPreviewTest do
  @moduledoc """
  The vision preview cycles through its readings -- basic, plus, then the map,
  where the vision's queries actually are.

  Raw is not one of them. It is a lens over whichever reading is showing, so it
  toggles on its own button rather than making the cycle a lap of five.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo}
  alias RoomSanctum.Storage.GTFS.Stop

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "vis#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "T", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"}
      })

    Repo.insert!(%Stop{source_id: source.id, stop_id: "s1", stop_name: "Park St",
                       stop_lat: 42.3564, stop_lon: -71.0624})

    {:ok, query} =
      Configuration.create_query(%{
        name: "Park St", notes: "", source_id: source.id, user_id: user.id,
        query: %{"__type__" => "gtfs", "stop" => "s1"}
      })

    {:ok, vision} =
      Configuration.create_vision(%{name: "Commute", user_id: user.id, query_ids: [query.id]})

    %{conn: log_in_user(conn, user), vision: vision}
  end

  test "the preview opens on basic", %{conn: conn, vision: vision} do
    {:ok, _live, html} = live(conn, Routes.vision_show_path(conn, :show, vision))

    assert html =~ ">basic<"
  end

  test "basic, then plus, then map, then round again", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

    assert render_click(live, "toggle-preview-mode", %{}) =~ ">plus<"
    assert render_click(live, "toggle-preview-mode", %{}) =~ ">map<"
    assert render_click(live, "toggle-preview-mode", %{}) =~ ">basic<"
  end

  describe "the raw lens" do
    test "it is off to begin with, and is its own button", %{conn: conn, vision: vision} do
      {:ok, _live, html} = live(conn, Routes.vision_show_path(conn, :show, vision))

      assert html =~ ~s(phx-click="toggle-preview-raw")
      assert html =~ "btn-ghost"
    end

    test "turning it on does not move you off the reading you are on", %{
      conn: conn,
      vision: vision
    } do
      {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

      raw = render_click(live, "toggle-preview-raw", %{})

      assert raw =~ ">basic<"
      assert raw =~ "btn-accent"
    end

    test "it survives a change of reading, and turns off again", %{conn: conn, vision: vision} do
      {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

      render_click(live, "toggle-preview-raw", %{})
      plus = render_click(live, "toggle-preview-mode", %{})

      assert plus =~ ">plus<"
      assert plus =~ "btn-accent"

      assert render_click(live, "toggle-preview-raw", %{}) =~ "btn-ghost"
    end

    test "the map has no condensed data to read, so it offers no lens", %{
      conn: conn,
      vision: vision
    } do
      {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

      render_click(live, "toggle-preview-mode", %{})
      map = render_click(live, "toggle-preview-mode", %{})

      assert map =~ ">map<"
      refute map =~ ~s(phx-click="toggle-preview-raw")
    end

    test "a raw map is still a map, not a page of JSON", %{conn: conn, vision: vision} do
      {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

      render_click(live, "toggle-preview-raw", %{})
      render_click(live, "toggle-preview-mode", %{})
      map = render_click(live, "toggle-preview-mode", %{})

      assert map =~ "Nothing to place yet"
    end
  end

  test "the map says so rather than drawing an empty world", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

    render_click(live, "toggle-preview-mode", %{})
    map = render_click(live, "toggle-preview-mode", %{})

    # nothing has come back from the vision worker yet
    assert map =~ "Nothing to place yet"
    refute map =~ ~s(id="vision-map")
  end

  test "leaving the map takes it off the page", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

    render_click(live, "toggle-preview-mode", %{})
    render_click(live, "toggle-preview-mode", %{})
    back = render_click(live, "toggle-preview-mode", %{})

    refute back =~ ~s(id="vision-map")
  end
end
