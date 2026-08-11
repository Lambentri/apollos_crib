defmodule RoomSanctumWeb.QueryPlacementTest do
  @moduledoc """
  Where a query sits on a map.

  No query in this system carries a geom, so a query's position is always
  derived: a stop's coordinates, a dock's, or the foci it was pointed at.
  """
  use RoomSanctumWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.{Accounts, Configuration, Repo}
  alias RoomSanctum.Storage.GTFS.Stop

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "place#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home",
        user_id: user.id,
        # {lat, lon} -- how the foci picker writes it, verified against the
        # rows in the running database
        place: %Geo.Point{coordinates: {42.3601, -71.0589}, srid: 4326}
      })

    %{user: user, foci: foci}
  end

  defp source(user, type, config) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "#{type}", notes: "", type: type, enabled: true,
        user_id: user.id, config: config
      })

    source
  end

  defp render_queries(queries) do
    render_component(&query_geospatial_map/1, queries: queries, id: "t")
  end

  test "a foci-based query is placed at its foci", %{user: user, foci: foci} do
    src = source(user, :ephem, %{"__type__" => "ephem"})

    {:ok, query} =
      Configuration.create_query(%{
        name: "Weather at home", notes: "", source_id: src.id, user_id: user.id,
        query: %{"__type__" => "ephem", "foci_id" => foci.id}
      })

    html = render_queries([Configuration.get_query!(query.id)])

    assert html =~ ~s(type="query")
    assert html =~ ~s(name="Weather at home")
    assert html =~ ~s(lat="42.3601")
  end

  test "an icarus area query is placed at its foci too", %{user: user, foci: foci} do
    src = source(user, :icarus, %{"__type__" => "icarus"})

    query =
      Repo.insert!(%Configuration.Query{
        name: "Overhead", notes: "", source_id: src.id, user_id: user.id, public: true,
        query: %RoomSanctum.Configuration.Queries.Icarus{
          mode: :area, dist: 25, foci_id: foci.id
        }
      })

    html = render_queries([Configuration.get_query!(query.id)])

    assert html =~ ~s(name="Overhead")
    assert html =~ ~s(lat="42.3601")
  end

  test "a stop query is placed at the stop", %{user: user} do
    src = source(user, :gtfs, %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"})
    Repo.insert!(%Stop{source_id: src.id, stop_id: "s1", stop_name: "Park St",
                       stop_lat: 42.3564, stop_lon: -71.0624})

    {:ok, query} =
      Configuration.create_query(%{
        name: "Park St", notes: "", source_id: src.id, user_id: user.id,
        query: %{"__type__" => "gtfs", "stop" => "s1"}
      })

    html = render_queries([Configuration.get_query!(query.id)])

    assert html =~ ~s(lat="42.3564")
  end

  test "a query with nowhere to be is left off rather than placed at 0,0", %{user: user} do
    src = source(user, :bourse, %{"__type__" => "bourse"})

    {:ok, query} =
      Configuration.create_query(%{
        name: "AAPL", notes: "", source_id: src.id, user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    html = render_queries([Configuration.get_query!(query.id)])

    refute html =~ ~s(name="AAPL")
    refute html =~ ~s(lat="0")
  end

  test "a foci is read the way the app writes it, not the PostGIS way", %{user: user} do
    # Read as {lon, lat} this is latitude -71, which Leaflet clamps to the
    # south pole -- SFO drawn in Antarctica.
    {:ok, sfo} =
      Configuration.create_foci(%{
        name: "SFO",
        user_id: user.id,
        place: %Geo.Point{coordinates: {37.6226, -122.3843}, srid: 4326}
      })

    src = source(user, :ephem, %{"__type__" => "ephem"})

    {:ok, query} =
      Configuration.create_query(%{
        name: "Above SFO", notes: "", source_id: src.id, user_id: user.id,
        query: %{"__type__" => "ephem", "foci_id" => sfo.id}
      })

    html = render_queries([Configuration.get_query!(query.id)])

    assert html =~ ~s(lat="37.6226")
    assert html =~ ~s(lng="-122.3843")
    refute html =~ ~s(lat="-122.3843")
  end

  test "a foci stored somewhere impossible is left off rather than drawn at the pole",
       %{user: user} do
    {:ok, broken} =
      Configuration.create_foci(%{
        name: "Broken",
        user_id: user.id,
        place: %Geo.Point{coordinates: {-122.3843, 37.6226}, srid: 4326}
      })

    src = source(user, :ephem, %{"__type__" => "ephem"})

    {:ok, query} =
      Configuration.create_query(%{
        name: "Nowhere", notes: "", source_id: src.id, user_id: user.id,
        query: %{"__type__" => "ephem", "foci_id" => broken.id}
      })

    html = render_queries([Configuration.get_query!(query.id)])

    refute html =~ ~s(name="Nowhere")
  end

  test "placeable and unplaceable queries mix without either breaking", %{user: user, foci: foci} do
    ephem = source(user, :ephem, %{"__type__" => "ephem"})
    markets = source(user, :bourse, %{"__type__" => "bourse"})

    {:ok, a} =
      Configuration.create_query(%{
        name: "Weather", notes: "", source_id: ephem.id, user_id: user.id,
        query: %{"__type__" => "ephem", "foci_id" => foci.id}
      })

    {:ok, b} =
      Configuration.create_query(%{
        name: "Markets", notes: "", source_id: markets.id, user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    html = render_queries(Enum.map([a, b], &Configuration.get_query!(&1.id)))

    assert html =~ ~s(name="Weather")
    refute html =~ ~s(name="Markets")
  end
end
