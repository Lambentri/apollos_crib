defmodule RoomSanctum.NearbyStopsTest do
  @moduledoc """
  Which stops count as near a point.

  A GTFS feed keeps more than platforms in its stops table: stations, station
  entrances, lifts, stairwells and pathway nodes all live there, told apart by
  `location_type`, and only a platform appears in stop_times. The five things
  nearest a station entrance are usually five of that station's own nodes.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Repo, Storage}

  # Medford/Tufts, which is where this went wrong.
  @here %Geo.Point{coordinates: {-71.11553, 42.40837}, srid: 4326}

  defp stop(source_id, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {1, _} =
      Repo.insert_all(
        "gtfs_stops",
        [
          Map.merge(
            %{
              source_id: source_id,
              stop_id: attrs.stop_id,
              stop_name: attrs.stop_name,
              stop_lat: attrs.lat,
              stop_lon: attrs.lon,
              location_type: attrs[:location_type],
              inserted_at: now,
              updated_at: now
            },
            %{}
          )
        ]
      )

    :ok
  end

  setup do
    # gtfs_stops has a foreign key to the source, so one has to exist.
    {:ok, user} =
      RoomSanctum.Accounts.register_user(%{
        email: "stops#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      RoomSanctum.Configuration.create_source(%{
        name: "Feed",
        type: :gtfs,
        config: %{},
        enabled: true,
        user_id: user.id
      })

    %{source_id: source.id}
  end

  test "a pathway node is not somewhere you can board", %{source_id: source_id} do
    # Closer, but you cannot catch anything from a stairwell.
    stop(source_id, %{stop_id: "node-stairs", stop_name: "Stairs", lat: 42.40838, lon: -71.11554, location_type: "3"})
    stop(source_id, %{stop_id: "70511", stop_name: "Platform", lat: 42.4090, lon: -71.1160, location_type: "0"})

    assert [%{stop_id: "70511"}] = Storage.nearby_stops(source_id, @here, 5)
  end

  test "a station is not a platform either", %{source_id: source_id} do
    stop(source_id, %{stop_id: "place-mdftf", stop_name: "Station", lat: 42.40838, lon: -71.11554, location_type: "1"})
    stop(source_id, %{stop_id: "70511", stop_name: "Platform", lat: 42.4090, lon: -71.1160, location_type: "0"})

    assert [%{stop_id: "70511"}] = Storage.nearby_stops(source_id, @here, 5)
  end

  test "a feed that leaves location_type empty still answers", %{source_id: source_id} do
    # It is optional in the spec, and an absent one means a stop.
    stop(source_id, %{stop_id: "plain", stop_name: "Plain", lat: 42.4084, lon: -71.1156, location_type: nil})
    stop(source_id, %{stop_id: "blank", stop_name: "Blank", lat: 42.4085, lon: -71.1157, location_type: ""})

    assert length(Storage.nearby_stops(source_id, @here, 5)) == 2
  end

  test "a radius keeps nearest from meaning nearest in the world", %{source_id: source_id} do
    stop(source_id, %{stop_id: "close", stop_name: "Close", lat: 42.4090, lon: -71.1160, location_type: "0"})
    # San Francisco.
    stop(source_id, %{stop_id: "far", stop_name: "Far", lat: 37.7749, lon: -122.4194, location_type: "0"})

    # Without one, a foci nowhere near a source still gets that source's
    # closest stops -- an ocean away, and nothing saying they are not near.
    assert length(Storage.nearby_stops(source_id, @here, 5)) == 2
    assert [%{stop_id: "close"}] = Storage.nearby_stops(source_id, @here, 5, 800)
  end
end
