defmodule RoomGtfs.StopsWantedTest do
  @moduledoc """
  What the realtime worker asks the database about.

  These are the inputs that decide the size of a query which, unbounded, took
  the worker down against a national feed.
  """
  use ExUnit.Case, async: true

  alias TransitRealtime.{FeedEntity, FeedMessage, Position, VehiclePosition}

  defp feed(vehicles) do
    %FeedMessage{
      header: %TransitRealtime.FeedHeader{gtfs_realtime_version: "2.0"},
      entity: Enum.map(vehicles, &%FeedEntity{id: "e", vehicle: &1})
    }
  end

  defp wanted(feed), do: :erlang.apply(RoomGtfs.Worker.RT, :stops_wanted_for_test, [feed])

  test "a vehicle that says where it is needs no lookup" do
    f = feed([%VehiclePosition{stop_id: "S1", position: %Position{latitude: 1.0, longitude: 2.0}}])

    assert wanted(f) == []
  end

  test "a vehicle that names a stop and no position needs that stop" do
    assert wanted(feed([%VehiclePosition{stop_id: "S1", position: nil}])) == ["S1"]
  end

  test "a vehicle with neither is not a lookup" do
    assert wanted(feed([%VehiclePosition{stop_id: nil, position: nil}])) == []
  end

  test "a stop named by many vehicles is asked for once" do
    vehicles = for _ <- 1..50, do: %VehiclePosition{stop_id: "S1", position: nil}

    assert wanted(feed(vehicles)) == ["S1"]
  end

  test "a position missing a coordinate is not a position" do
    f = feed([%VehiclePosition{stop_id: "S1", position: %Position{latitude: nil, longitude: 2.0}}])

    assert wanted(f) == ["S1"]
  end

  test "an empty feed asks for nothing" do
    assert wanted(feed([])) == []
  end
end
