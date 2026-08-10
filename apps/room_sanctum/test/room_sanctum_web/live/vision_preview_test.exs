defmodule RoomSanctumWeb.VisionPreviewTest do
  @moduledoc """
  The vision preview cycles through its visualizers. The map is the third:
  where the vision's queries actually are.
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

  test "basic, then raw, then map, then round again", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, Routes.vision_show_path(conn, :show, vision))

    assert render_click(live, "toggle-preview-mode", %{}) =~ ">raw<"
    assert render_click(live, "toggle-preview-mode", %{}) =~ ">map<"
    assert render_click(live, "toggle-preview-mode", %{}) =~ ">basic<"
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
