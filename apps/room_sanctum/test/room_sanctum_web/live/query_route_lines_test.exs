defmodule RoomSanctumWeb.QueryRouteLinesTest do
  @moduledoc """
  A stop query's map draws the routes calling at that stop, not every shape in
  the feed -- MBTA alone is hundreds of routes.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo}
  alias RoomSanctum.Storage.GTFS.{Route, Shape, Stop, StopTime, Trip}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "qrl#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "MBTA", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://example.test/g.zip", "tz" => "UTC"}
      })

    sid = source.id

    for stop_id <- ["here", "elsewhere"] do
      Repo.insert!(%Stop{source_id: sid, stop_id: stop_id, stop_name: stop_id,
                         stop_lat: 42.38, stop_lon: -71.11})
    end

    # A and B call at "here"; C and D are elsewhere in the system
    for {rid, stops} <- [{"A", ["here"]}, {"B", ["here", "elsewhere"]},
                         {"C", ["elsewhere"]}, {"D", ["elsewhere"]}] do
      Repo.insert!(%Route{source_id: sid, route_id: rid, route_type: "3", route_short_name: rid})
      Repo.insert!(%Trip{source_id: sid, route_id: rid, trip_id: "T#{rid}",
                         shape_id: "SH#{rid}", service_id: "s"})

      for i <- 1..4 do
        Repo.insert!(%Shape{source_id: sid, shape_id: "SH#{rid}", shape_pt_sequence: i,
                            shape_pt_lat: 42.38 + i / 1000, shape_pt_lon: -71.11})
      end

      for {stop_id, seq} <- Enum.with_index(stops) do
        Repo.insert!(%StopTime{source_id: sid, trip_id: "T#{rid}", stop_id: stop_id,
                               stop_sequence: seq})
      end
    end

    {:ok, query} =
      Configuration.create_query(%{
        name: "Here", notes: "", source_id: sid, user_id: user.id,
        query: %{"__type__" => "gtfs", "stop" => "here"}
      })

    %{conn: log_in_user(conn, user), query: query, sid: sid}
  end

  defp drawn_lines(html) do
    Regex.scan(~r/<leaflet-line[^>]*id="geospatial-map-line-([^"]+)"/, html)
    |> Enum.map(&List.last/1)
    |> Enum.sort()
  end

  test "only the routes calling at the stop are drawn", %{conn: conn, query: query, sid: sid} do
    {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))

    html = render_click(live, "toggle-route-lines", %{})

    assert drawn_lines(html) == ["#{sid}-A", "#{sid}-B"]
  end

  test "the rest of the system is left off", %{conn: conn, query: query, sid: sid} do
    {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))
    html = render_click(live, "toggle-route-lines", %{})

    refute html =~ "#{sid}-C"
    refute html =~ "#{sid}-D"
  end

  test "nothing is drawn until asked for", %{conn: conn, query: query} do
    {:ok, _live, html} = live(conn, Routes.query_show_path(conn, :show, query))

    assert drawn_lines(html) == []
  end

  test "toggling off clears them again", %{conn: conn, query: query} do
    {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))

    render_click(live, "toggle-route-lines", %{})
    off = render_click(live, "toggle-route-lines", %{})

    assert drawn_lines(off) == []
  end

  test "a stop nothing calls at draws nothing, rather than everything", %{conn: conn, sid: sid, query: q} do
    Repo.insert!(%Stop{source_id: sid, stop_id: "orphan", stop_name: "orphan",
                       stop_lat: 42.4, stop_lon: -71.0})

    {:ok, orphan} =
      Configuration.create_query(%{
        name: "Orphan", notes: "", source_id: sid, user_id: q.user_id,
        query: %{"__type__" => "gtfs", "stop" => "orphan"}
      })

    {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, orphan))
    html = render_click(live, "toggle-route-lines", %{})

    assert drawn_lines(html) == []
  end
end
