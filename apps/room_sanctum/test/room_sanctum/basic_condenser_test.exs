defmodule RoomSanctum.BasicCondenserTest do
  @moduledoc """
  The route's name and colour are already sitting in the arrival row, so Basic
  carries them too rather than making Plus the only place a line looks like
  itself.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Condenser.BasicMQTT

  defp arrival(route_attrs \\ %{}, attrs \\ %{}) do
    Map.merge(
      %{
        arrival_time: "12:30:00",
        arrival_time_live_ts: nil,
        trip_id: "t1",
        tz: "America/New_York",
        trip: %{
          trip_headsign: "Downtown",
          route_id: "r_9931",
          direction: %{direction: "Inbound"},
          route:
            Map.merge(
              %{
                route_id: "r_9931",
                route_type: "3",
                route_short_name: "22",
                route_long_name: "Crosstown",
                route_color: "FFC72C",
                route_text_color: "000000"
              },
              route_attrs
            )
        }
      },
      attrs
    )
  end

  test "a route says what it is called and what colour it is" do
    [route] = BasicMQTT.condense_data({1, :gtfs}, [arrival()])

    assert route.route_name == "22"
    assert route.route_long == "Crosstown"
    assert route.color == "#FFC72C"
    assert route.text_color == "#000000"
  end

  test "the id anything downstream keys on is untouched" do
    [route] = BasicMQTT.condense_data({1, :gtfs}, [arrival()])

    assert route.route == "r_9931"
    assert route.dest == "Downtown"
    assert route.dir == "Inbound"
    assert route.mode == "Bus"
  end

  test "the times are still condensed the way they were" do
    [route] =
      BasicMQTT.condense_data({1, :gtfs}, [
        arrival(%{}, %{arrival_time: "12:30:00"}),
        arrival(%{}, %{arrival_time: "12:45:00"})
      ])

    assert route.times == ["12:30:00", "12:45:00"]
    # Nothing live was reported, so the key is dropped, exactly as before.
    refute Map.has_key?(route, :times_live)
  end

  test "a live time still wins, and is read in the stop's timezone" do
    [route] =
      BasicMQTT.condense_data({1, :gtfs}, [
        arrival(%{}, %{arrival_time_live_ts: 1_704_130_260})
      ])

    assert route.times_live == [~T[12:31:00]]
  end

  test "a route map missing those columns entirely does not raise" do
    # MapData rescues around this and draws nothing when it blows up, so a
    # KeyError here is an empty map popup rather than an error anyone sees.
    bare = %{
      arrival_time: "12:30:00",
      arrival_time_live_ts: nil,
      tz: "America/New_York",
      trip: %{
        trip_headsign: "Downtown",
        route_id: "71",
        direction: %{direction: "Inbound"},
        route: %{route_type: "3"}
      }
    }

    assert [route] = BasicMQTT.condense_data({1, :gtfs}, [bare])
    assert route.route_name == "71"
    assert route.color == nil
  end

  test "a feed that names and colours nothing still condenses" do
    route_attrs = %{
      route_short_name: nil,
      route_long_name: nil,
      route_color: nil,
      route_text_color: nil
    }

    [route] = BasicMQTT.condense_data({1, :gtfs}, [arrival(route_attrs)])

    assert route.route_name == "r_9931"
    assert route.route_long == nil
    assert route.color == nil
  end
end
