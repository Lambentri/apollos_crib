defmodule RoomSanctumWeb.QueryIndexAircraftTest do
  @moduledoc """
  The query index draws every query the user owns, so live aircraft are a layer
  on it rather than its subject: two area queries in different cities fill the
  map and zoom it out to fit them, burying everything else.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "idx#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  defp icarus_query(user, name) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "adsb #{name}",
        notes: "",
        type: :icarus,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "icarus", "endpoint" => "https://example.test/v3"}
      })

    # Inserted directly: the icarus query changeset validates against
    # RoomIcarus.Classify, and room_icarus is not a dependency of this app, so
    # it cannot be loaded here.
    RoomSanctum.Repo.insert!(%RoomSanctum.Configuration.Query{
      name: name,
      notes: "",
      source_id: source.id,
      user_id: user.id,
      public: true,
      query: %RoomSanctum.Configuration.Queries.Icarus{mode: :area, dist: 25, foci_id: 1}
    })
  end

  defp bourse_query(user) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "Markets",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    {:ok, query} =
      Configuration.create_query(%{
        name: "AAPL",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    query
  end

  test "aircraft are off when the map opens", %{conn: conn, user: user} do
    icarus_query(user, "BOS")

    {:ok, live, _html} = live(conn, Routes.query_index_path(conn, :index))
    html = live |> element("button", "Map View") |> render_click()

    refute html =~ ~s(type="aircraft")
    assert html =~ "Show aircraft"
  end

  test "the toggle is offered when an icarus query is on the map", %{conn: conn, user: user} do
    icarus_query(user, "BOS")

    {:ok, live, _html} = live(conn, Routes.query_index_path(conn, :index))
    html = live |> element("button", "Map View") |> render_click()

    assert html =~ ~s(phx-click="toggle-aircraft")
  end

  test "no icarus query means no aircraft toggle to clutter the map", %{conn: conn, user: user} do
    bourse_query(user)

    {:ok, live, _html} = live(conn, Routes.query_index_path(conn, :index))
    html = live |> element("button", "Map View") |> render_click()

    refute html =~ ~s(phx-click="toggle-aircraft")
  end

  test "the toggle flips, and flips back", %{conn: conn, user: user} do
    icarus_query(user, "BOS")

    {:ok, live, _html} = live(conn, Routes.query_index_path(conn, :index))
    live |> element("button", "Map View") |> render_click()

    on = render_click(live, "toggle-aircraft", %{})
    assert on =~ "Hide aircraft"

    off = render_click(live, "toggle-aircraft", %{})
    assert off =~ "Show aircraft"
    refute off =~ ~s(type="aircraft")
  end

  test "several icarus queries still leave the layer off", %{conn: conn, user: user} do
    # the reported shape: area queries in two cities, which between them cover
    # most of the country once both are plotted
    icarus_query(user, "BOS")
    icarus_query(user, "SFO")

    {:ok, live, _html} = live(conn, Routes.query_index_path(conn, :index))
    html = live |> element("button", "Map View") |> render_click()

    refute html =~ ~s(type="aircraft")
  end
end
