defmodule RoomSanctum.GtfsRouteLinesTest do
  @moduledoc """
  Route geometry for the map's route-line layer, and the linked_datasets.txt
  parsing that wires up GTFS-RT automatically.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Accounts, Configuration, Repo, Storage}
  alias RoomSanctum.Storage.GTFS.{Route, Shape, Stop, StopTime, Trip}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "lines#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Feed",
        notes: "",
        type: :gtfs,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://example.test/g.zip", "tz" => "UTC"}
      })

    %{source: source, sid: source.id}
  end

  defp route(sid, id, opts \\ []) do
    Repo.insert!(%Route{
      source_id: sid,
      route_id: id,
      route_type: Keyword.get(opts, :type, "3"),
      route_color: Keyword.get(opts, :color)
    })
  end

  defp trip(sid, route_id, trip_id, shape_id \\ nil) do
    Repo.insert!(%Trip{
      source_id: sid,
      route_id: route_id,
      trip_id: trip_id,
      shape_id: shape_id,
      service_id: "svc"
    })
  end

  defp shape_points(sid, shape_id, count) do
    for i <- 1..count do
      Repo.insert!(%Shape{
        source_id: sid,
        shape_id: shape_id,
        shape_pt_lat: 37.0 + i / 10_000,
        shape_pt_lon: -122.0,
        shape_pt_sequence: i
      })
    end
  end

  defp stops_for(sid, trip_id, count) do
    for i <- 1..count do
      stop_id = "#{trip_id}-s#{i}"
      Repo.insert!(%Stop{source_id: sid, stop_id: stop_id, stop_name: stop_id,
                         stop_lat: 38.0 + i / 1000, stop_lon: -122.0})
      Repo.insert!(%StopTime{source_id: sid, trip_id: trip_id, stop_id: stop_id,
                             stop_sequence: i})
    end
  end

  defp line_for(lines, id), do: Enum.find(lines, &(&1.id == id))

  describe "route geometry" do
    test "a route with a shape uses the drawn alignment", %{sid: sid} do
      route(sid, "R1")
      trip(sid, "R1", "T1", "SH1")
      shape_points(sid, "SH1", 12)
      # stops exist too, and must lose to the shape
      stops_for(sid, "T1", 3)

      line = Storage.list_route_lines(sid) |> line_for("R1")

      assert length(line.points) == 12
      assert [lat, lon] = hd(line.points)
      # shapes sit at 37.x, the stop fallback at 38.x
      assert_in_delta lat, 37.0, 0.01
      assert lon == -122.0
    end

    test "a route with no shape falls back to its stop sequence", %{sid: sid} do
      route(sid, "R2")
      trip(sid, "R2", "T2", nil)
      stops_for(sid, "T2", 4)

      line = Storage.list_route_lines(sid) |> line_for("R2")

      assert length(line.points) == 4
      assert [lat, _lon] = hd(line.points)
      assert_in_delta lat, 38.0, 0.01
    end

    test "shaped and unshaped routes coexist in one feed", %{sid: sid} do
      route(sid, "SHAPED")
      trip(sid, "SHAPED", "TA", "SHA")
      shape_points(sid, "SHA", 5)

      route(sid, "PLAIN")
      trip(sid, "PLAIN", "TB", nil)
      stops_for(sid, "TB", 3)

      lines = Storage.list_route_lines(sid)

      assert length(lines) == 2
      assert length(line_for(lines, "SHAPED").points) == 5
      assert length(line_for(lines, "PLAIN").points) == 3
    end

    test "an empty shape_id is treated as no shape", %{sid: sid} do
      route(sid, "R3")
      trip(sid, "R3", "T3", "")
      stops_for(sid, "T3", 3)

      assert length(Storage.list_route_lines(sid) |> line_for("R3") |> Map.fetch!(:points)) == 3
    end

    test "a long shape is decimated but still ends where the route ends", %{sid: sid} do
      route(sid, "LONG")
      trip(sid, "LONG", "TL", "SHL")
      shape_points(sid, "SHL", 1000)

      line = Storage.list_route_lines(sid) |> line_for("LONG")

      assert length(line.points) <= 200, "got #{length(line.points)} points"
      assert length(line.points) > 50, "decimated too far: #{length(line.points)}"
      # the 1000th point, i.e. the true end of the line
      assert List.last(line.points) == [37.0 + 1000 / 10_000, -122.0]
      assert hd(line.points) == [37.0 + 1 / 10_000, -122.0]
    end

    test "a one-point shape is not a line", %{sid: sid} do
      route(sid, "DOT")
      trip(sid, "DOT", "TD", "SHD")
      shape_points(sid, "SHD", 1)

      assert Storage.list_route_lines(sid) |> line_for("DOT") == nil
    end

    test "route_color gains the hash CSS needs, and absence is tolerated", %{sid: sid} do
      route(sid, "BARE", color: "FFC72C")
      trip(sid, "BARE", "T4", "SH4")
      shape_points(sid, "SH4", 3)

      route(sid, "HASHED", color: "#0a5")
      trip(sid, "HASHED", "T5", "SH5")
      shape_points(sid, "SH5", 3)

      route(sid, "NONE", color: nil)
      trip(sid, "NONE", "T6", "SH6")
      shape_points(sid, "SH6", 3)

      lines = Storage.list_route_lines(sid)

      assert line_for(lines, "BARE").color == "#FFC72C"
      assert line_for(lines, "HASHED").color == "#0a5"
      assert line_for(lines, "NONE").color == nil
    end

    test "a feed with no geometry at all yields nothing rather than raising", %{sid: sid} do
      route(sid, "EMPTY")
      assert Storage.list_route_lines(sid) == []
    end

    test "ids stay unique when several feeds are drawn on one map", %{sid: sid, source: source} do
      route(sid, "1")
      trip(sid, "1", "T1", "SH1")
      shape_points(sid, "SH1", 3)

      {:ok, other} =
        Configuration.create_source(%{
          name: "Other feed",
          notes: "",
          type: :gtfs,
          enabled: true,
          user_id: source.user_id,
          config: %{"__type__" => "gtfs", "url" => "https://example.test/o.zip", "tz" => "UTC"}
        })

      # same route_id in a different feed -- the ids must not collide
      route(other.id, "1")
      trip(other.id, "1", "T1", "SH1")
      shape_points(other.id, "SH1", 3)

      ids = Storage.list_route_lines([sid, other.id]) |> Enum.map(& &1.id) |> Enum.sort()

      assert ids == Enum.sort(["#{other.id}-1", "#{sid}-1"])
    end
  end

  describe "routes serviced by a stop" do
    setup %{sid: sid} do
      for stop_id <- ["shared", "only_a", "only_b"] do
        Repo.insert!(%Stop{source_id: sid, stop_id: stop_id, stop_name: stop_id,
                           stop_lat: 37.0, stop_lon: -122.0})
      end

      # A calls at shared + only_a, B at shared + only_b, C at only_b alone
      for {rid, stops} <- [{"A", ["shared", "only_a"]}, {"B", ["shared", "only_b"]}, {"C", ["only_b"]}] do
        route(sid, rid)
        trip(sid, rid, "T#{rid}", nil)

        for {stop_id, seq} <- Enum.with_index(stops) do
          Repo.insert!(%StopTime{source_id: sid, trip_id: "T#{rid}", stop_id: stop_id,
                                 stop_sequence: seq})
        end
      end

      :ok
    end

    test "returns every route calling there, and only those", %{sid: sid} do
      assert Storage.routes_serving_stop(sid, "shared") |> Enum.sort() == ["A", "B"]
      assert Storage.routes_serving_stop(sid, "only_a") |> Enum.sort() == ["A"]
      assert Storage.routes_serving_stop(sid, "only_b") |> Enum.sort() == ["B", "C"]
    end

    test "a route calling twice is listed once", %{sid: sid} do
      Repo.insert!(%StopTime{source_id: sid, trip_id: "TA", stop_id: "shared", stop_sequence: 99})

      assert Storage.routes_serving_stop(sid, "shared") |> Enum.sort() == ["A", "B"]
    end

    test "an unknown stop serves nothing", %{sid: sid} do
      assert Storage.routes_serving_stop(sid, "nope") == []
    end

    test "does not leak across feeds", %{sid: sid, source: source} do
      {:ok, other} =
        Configuration.create_source(%{
          name: "Elsewhere",
          notes: "",
          type: :gtfs,
          enabled: true,
          user_id: source.user_id,
          config: %{"__type__" => "gtfs", "url" => "https://example.test/e.zip", "tz" => "UTC"}
        })

      assert Storage.routes_serving_stop(other.id, "shared") == []
      assert sid != other.id
    end
  end
end
