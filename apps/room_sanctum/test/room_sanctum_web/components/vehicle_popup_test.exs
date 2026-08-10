defmodule RoomSanctumWeb.VehiclePopupTest do
  @moduledoc """
  A realtime vehicle position carries only ids, so what the marker says has to
  come from the static feed.
  """
  use RoomSanctumWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.{Accounts, Configuration, Repo, Storage}
  alias RoomSanctum.Storage.GTFS.{Direction, Route, Trip}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "veh#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Muni", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://example.test/g.zip", "tz" => "UTC"}
      })

    Repo.insert!(%Route{source_id: source.id, route_id: "R38", route_type: "3",
                        route_short_name: "38", route_long_name: "Geary"})
    Repo.insert!(%Trip{source_id: source.id, trip_id: "T1", route_id: "R38",
                       direction_id: 0, trip_headsign: "Geary + 33rd Avenue", service_id: "s"})
    Repo.insert!(%Direction{source_id: source.id, route_id: "R38", direction_id: 0,
                            direction: "Outbound"})

    %{sid: source.id}
  end

  defp vehicle(attrs \\ %{}) do
    Map.merge(
      %{vehicle_id: "V1", trip_id: "T1", route_id: "R38",
        latitude: 37.78, longitude: -122.44, bearing: 90.0, timestamp: nil},
      attrs
    )
  end

  describe "looking up what a vehicle is doing" do
    test "resolves route, destination, direction and mode", %{sid: sid} do
      assert %{"T1" => ctx} = Storage.vehicle_context(sid, ["T1"])

      assert ctx.route == "38"
      assert ctx.dest == "Geary + 33rd Avenue"
      assert ctx.direction == "Outbound"
      assert ctx.mode == "Bus"
    end

    test "falls back to the long name when there is no short one", %{sid: sid} do
      Repo.insert!(%Route{source_id: sid, route_id: "R2", route_type: "1",
                          route_short_name: "  ", route_long_name: "Market Street Subway"})
      Repo.insert!(%Trip{source_id: sid, trip_id: "T2", route_id: "R2", service_id: "s"})

      assert Storage.vehicle_context(sid, ["T2"])["T2"].route == "Market Street Subway"
    end

    test "a trip with no direction row still resolves the rest", %{sid: sid} do
      Repo.insert!(%Route{source_id: sid, route_id: "R9", route_type: "4",
                          route_short_name: "F", route_long_name: "Ferry"})
      Repo.insert!(%Trip{source_id: sid, trip_id: "T9", route_id: "R9",
                         direction_id: 1, trip_headsign: "Sausalito", service_id: "s"})

      ctx = Storage.vehicle_context(sid, ["T9"])["T9"]

      assert ctx.direction == nil
      assert ctx.dest == "Sausalito"
      assert ctx.mode == "Ferry"
    end

    test "an unknown trip is simply absent", %{sid: sid} do
      assert Storage.vehicle_context(sid, ["nope"]) == %{}
    end

    test "no trips means no query", %{sid: sid} do
      assert Storage.vehicle_context(sid, []) == %{}
    end

    test "does not reach into another feed", %{sid: sid} do
      assert Storage.vehicle_context(sid + 9999, ["T1"]) == %{}
    end
  end

  describe "vehicles running a trip the schedule does not have" do
    test "still say which route and mode, from the route alone", %{sid: sid} do
      # shuttles and added trips: MBTA runs about one vehicle in eight this way
      vehicles = [vehicle(%{vehicle_id: "shuttle", trip_id: "ADDED-1", route_id: "R38"})]

      [enriched] = Storage.with_trip_context(vehicles, sid)

      assert enriched.route == "38"
      assert enriched.mode == "Bus"
      # the schedule is what knows these, and it does not know this trip
      assert enriched.dest == nil
      assert enriched.direction == nil
    end

    test "a vehicle on an unknown route is left as it came", %{sid: sid} do
      vehicles = [vehicle(%{trip_id: "ADDED-2", route_id: "NOPE"})]

      [enriched] = Storage.with_trip_context(vehicles, sid)

      refute Map.has_key?(enriched, :route)
      assert enriched.vehicle_id == "V1"
    end

    test "scheduled and unscheduled vehicles are enriched in one pass", %{sid: sid} do
      vehicles = [
        vehicle(%{vehicle_id: "scheduled", trip_id: "T1"}),
        vehicle(%{vehicle_id: "added", trip_id: "ADDED-3", route_id: "R38"})
      ]

      [scheduled, added] = Storage.with_trip_context(vehicles, sid)

      assert scheduled.dest == "Geary + 33rd Avenue"
      assert added.route == "38" and added.dest == nil
    end

    test "no vehicles means no queries at all", %{sid: sid} do
      assert Storage.with_trip_context([], sid) == []
    end
  end

  describe "what the marker carries" do
    test "the popup gets route, destination, direction and mode" do
      html =
        render_component(&query_geospatial_map/1,
          queries: [],
          vehicle_positions: [
            vehicle(%{route: "38", dest: "Geary + 33rd Avenue",
                      direction: "Outbound", mode: "Bus"})
          ]
        )

      assert html =~ ~s(route="38")
      assert html =~ ~s(dest="Geary + 33rd Avenue")
      assert html =~ ~s(direction="Outbound")
      assert html =~ ~s(mode="Bus")
      assert html =~ ~s(vehicle-id="V1")
    end

    test "the label says the route and where it is heading" do
      html =
        render_component(&query_geospatial_map/1,
          queries: [],
          vehicle_positions: [vehicle(%{route: "38", dest: "Geary + 33rd Avenue"})]
        )

      assert html =~ ~s(name="38 to Geary + 33rd Avenue")
      # never the placeholder that shipped before
      refute html =~ ~s(name="Marker")
    end

    test "an unscheduled vehicle falls back to its own id rather than nothing" do
      html =
        render_component(&query_geospatial_map/1,
          queries: [],
          vehicle_positions: [vehicle(%{trip_id: nil})]
        )

      assert html =~ ~s(name="V1")
    end

    test "missing context is left out, not printed as null" do
      html =
        render_component(&query_geospatial_map/1,
          queries: [],
          vehicle_positions: [vehicle(%{route: "38"})]
        )

      refute html =~ "null"
      assert html =~ ~s(route="38")
    end
  end
end
