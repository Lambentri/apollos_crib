defmodule RoomSanctumWeb.AirNowTest do
  @moduledoc """
  AirNow on the maps.

  The feed replaces its observations every hour, so a reading and the station
  that made it are the same record -- "the stations" are just the current
  observations.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo, Storage}
  alias RoomSanctum.Storage.AirNow.HourlyObsData

  # Home is in Boston; Maputo is 12,000km away and must never be "nearby".
  @stations [
    {"BOS-1", "Kenmore Sq", 42.3489, -71.0977, 52},
    {"BOS-2", "North End", 42.3631, -71.0542, 41},
    {"FAR-1", "Maputo", -25.9038, 32.6284, 18}
  ]

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "air#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "AirNow", notes: "", type: :aqi, enabled: true,
        user_id: user.id, config: %{"__type__" => "aqi"}
      })

    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home", user_id: user.id,
        place: %Geo.Point{coordinates: {-71.0589, 42.3601}, srid: 4326}
      })

    for {aqsid, name, lat, lon, pm} <- @stations do
      Repo.insert!(%HourlyObsData{
        source_id: source.id, aqsid: aqsid, site_name: name,
        lat: lat, lon: lon,
        point: %Geo.Point{coordinates: {lon, lat}, srid: 4326},
        pm25_aqi: pm, pm25_measured: true,
        valid_date: ~D[2026-08-11], valid_time: ~T[16:00:00],
        reporting_areas: [name]
      })
    end

    %{conn: log_in_user(conn, user), user: user, source: source, foci: foci}
  end

  defp foci_query(ctx, name \\ "Air at home") do
    {:ok, query} =
      Configuration.create_query(%{
        name: name, notes: "", source_id: ctx.source.id, user_id: ctx.user.id,
        query: %{"__type__" => "aqi", "foci_id" => ctx.foci.id}
      })

    query
  end

  describe "finding stations" do
    test "nearest returns the closest first, and never the far one", ctx do
      names = Storage.nearest_aqi_stations(ctx.source.id, ctx.foci.id, 2) |> Enum.map(& &1.site_name)

      assert names == ["North End", "Kenmore Sq"]
      refute "Maputo" in names
    end

    test "every reporting station is listed for the source", ctx do
      ids = Storage.list_aqi_stations(ctx.source.id) |> Enum.map(& &1.aqsid) |> Enum.sort()

      assert ids == ["BOS-1", "BOS-2", "FAR-1"]
    end

    test "a station can be fetched by its aqs id", ctx do
      assert [station] = Storage.get_aqi_station(ctx.source.id, "BOS-1")
      assert station.site_name == "Kenmore Sq"
    end

    test "an unknown station is empty, not an error", ctx do
      assert Storage.get_aqi_station(ctx.source.id, "nope") == []
    end
  end

  describe "the headline reading" do
    test "is the worst sub-index, and says which" do
      assert HourlyObsData.overall_aqi(%{pm25_aqi: 52, ozone_aqi: 38, pm10_aqi: nil, no2_aqi: 12}) ==
               {52, "PM2.5"}

      assert HourlyObsData.overall_aqi(%{pm25_aqi: 12, ozone_aqi: 90, pm10_aqi: nil, no2_aqi: nil}) ==
               {90, "Ozone"}
    end

    test "a station reporting nothing has none" do
      assert HourlyObsData.overall_aqi(%{pm25_aqi: nil, ozone_aqi: nil, pm10_aqi: nil, no2_aqi: nil}) ==
               nil

      assert HourlyObsData.overall_aqi(nil) == nil
    end
  end

  describe "a query by station id" do
    test "is accepted without a foci", ctx do
      {:ok, query} =
        Configuration.create_query(%{
          name: "Just Kenmore", notes: "", source_id: ctx.source.id, user_id: ctx.user.id,
          query: %{"__type__" => "aqi", "aqsid" => "BOS-1"}
        })

      assert query.query.aqsid == "BOS-1"
      assert query.query.foci_id == nil
    end

    test "a query naming neither a foci nor a station is refused", ctx do
      assert {:error, _} =
               Configuration.create_query(%{
                 name: "Nowhere", notes: "", source_id: ctx.source.id, user_id: ctx.user.id,
                 query: %{"__type__" => "aqi"}
               })
    end

    test "a blank station id does not pass for one", ctx do
      assert {:error, _} =
               Configuration.create_query(%{
                 name: "Blank", notes: "", source_id: ctx.source.id, user_id: ctx.user.id,
                 query: %{"__type__" => "aqi", "aqsid" => "   "}
               })
    end
  end

  describe "the query page" do
    test "lists the station it answers with, then its neighbours", ctx do
      {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, foci_query(ctx)))

      assert html =~ "North End"
      assert html =~ "Kenmore Sq"
      # the nearest is marked out from the rest
      assert html =~ "fa-location-crosshairs"
    end

    test "shows each station's current reading", ctx do
      {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, foci_query(ctx)))

      assert html =~ "52"
      assert html =~ "41"
      assert html =~ "PM2.5"
    end

    test "puts them on its map", ctx do
      {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, foci_query(ctx)))

      assert length(Regex.scan(~r/marker-station_/, html)) == 3
    end

    test "a station-id query gets neighbours too", ctx do
      {:ok, query} =
        Configuration.create_query(%{
          name: "Just Kenmore", notes: "", source_id: ctx.source.id, user_id: ctx.user.id,
          query: %{"__type__" => "aqi", "aqsid" => "BOS-1"}
        })

      {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, query))

      assert html =~ "Kenmore Sq"
      assert html =~ "North End"
    end
  end

  describe "the source map" do
    test "shows every station, with its reading on the marker", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, ctx.source))
      send(live.pid, :update_sec)
      html = render_click(live, "toggle-view", %{})

      ids = Regex.scan(~r/marker-station_([A-Z0-9-]+)"/, html) |> Enum.map(&List.last/1) |> Enum.sort()

      assert ids == ["BOS-1", "BOS-2", "FAR-1"]
      assert html =~ "AQI 52"
    end

    test "a station can be turned into a query from the map", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, ctx.source))
      send(live.pid, :update_sec)
      render_click(live, "toggle-view", %{})

      render_click(live, "map-add-query", %{"station-id" => "BOS-2", "name" => "North End"})

      created =
        Configuration.get_queries(:source, ctx.source.id) |> Enum.find(&(&1.name == "North End"))

      assert created.query.aqsid == "BOS-2"
      assert created.query.foci_id == nil
    end

    test "a station that already has a query is not offered again", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, ctx.source))
      send(live.pid, :update_sec)
      render_click(live, "toggle-view", %{})
      render_click(live, "map-add-query", %{"station-id" => "BOS-2", "name" => "North End"})

      send(live.pid, :update_sec)
      html = render(live)

      assert html =~ ~s(data-has-query="1")
    end
  end
end
