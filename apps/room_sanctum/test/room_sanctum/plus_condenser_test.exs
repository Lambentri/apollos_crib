defmodule RoomSanctum.PlusCondenserTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Condenser.PlusMQTT

  defp route(attrs) do
    Map.merge(
      %{
        route_id: "22",
        route_type: "3",
        route_short_name: nil,
        route_long_name: nil,
        route_color: nil,
        route_text_color: nil
      },
      Map.new(attrs)
    )
  end

  defp arrival(attrs) do
    %{
      arrival_time: "12:30:00",
      arrival_time_live_ts: nil,
      stop_id: nil,
      arrival_time_live_delay: nil,
      arrival_time_live_uncertianty: nil,
      trip_id: "t1",
      tz: "America/New_York",
      trip: %{
        trip_headsign: "Downtown",
        trip_short_name: nil,
        bikes_allowed: nil,
        route_id: "22",
        direction: %{direction: "Inbound"},
        route: route(%{})
      }
    }
    |> Map.merge(Map.new(attrs))
  end

  test "keeps each arrival whole, in schedule order" do
    [route] =
      PlusMQTT.condense_data({1, :gtfs}, [
        arrival(arrival_time: "12:30:00"),
        arrival(arrival_time: "12:45:00")
      ])

    assert route.route == "22"
    assert route.dest == "Downtown"
    assert route.mode == "Bus"
    assert Enum.map(route.arrivals, & &1.time) == ["12:30:00", "12:45:00"]
  end

  test "carries the occupancy of the arrival it belongs to" do
    [route] =
      PlusMQTT.condense_data({1, :gtfs}, [
        arrival(occupancy: :FEW_SEATS_AVAILABLE, occupancy_pct: 40),
        arrival(arrival_time: "12:45:00")
      ])

    assert [first, second] = route.arrivals
    assert first.occupancy == :FEW_SEATS_AVAILABLE
    assert first.occupancy_pct == 40
    # An arrival the feed said nothing about says nothing, rather than
    # borrowing what the one before it reported.
    assert second.occupancy == nil
  end

  test "reads a live time in the stop's own timezone, with its delay" do
    # 2024-01-01 17:31:00Z is 12:31 in New York.
    [route] =
      PlusMQTT.condense_data({1, :gtfs}, [
        arrival(arrival_time_live_ts: 1_704_130_260, arrival_time_live_delay: 60)
      ])

    assert [%{time_live: ~T[12:31:00], delay: 60}] = route.arrivals
  end

  test "carries what the call says about itself, over what the trip says" do
    [route] =
      PlusMQTT.condense_data({1, :gtfs}, [
        arrival(
          stop_headsign: "Uptown - short",
          assigned_platform: "Track 3",
          stop_status: :SKIPPED,
          trip_status: :CANCELED,
          carriages: [%{sequence: 1, occupancy: :EMPTY}]
        )
      ])

    assert [a] = route.arrivals
    assert a.headsign == "Uptown - short"
    assert a.platform == "Track 3"
    assert a.stop_status == :SKIPPED
    assert a.trip_status == :CANCELED
    assert [%{occupancy: :EMPTY}] = a.carriages
  end

  test "an arrival the feed flagged nothing about is flagged as nothing" do
    [route] = PlusMQTT.condense_data({1, :gtfs}, [arrival([])])

    assert [a] = route.arrivals
    assert a.trip_status == nil
    assert a.stop_status == nil
    assert a.platform == nil
    assert a.headsign == nil
    assert a.carriages == []
  end

  describe "route presentation" do
    alias RoomSanctum.Condenser.BasicMQTT

    defp presented(attrs) do
      BasicMQTT.route_presentation(route(attrs), Map.get(attrs, :route_id, "22"))
    end

    test "the name on the front of the vehicle beats the internal id" do
      assert %{route_name: "22"} = presented(%{route_short_name: "22", route_id: "r_9931"})
    end

    test "the long name stands in when there is no short one" do
      assert %{route_name: "Orange Line"} =
               presented(%{route_long_name: "Orange Line", route_id: "r_9931"})
    end

    test "a feed naming its routes nothing at all still says the id" do
      assert %{route_name: "r_9931"} = presented(%{route_id: "r_9931"})
      assert %{route_name: "r_9931"} = presented(%{route_id: "r_9931", route_short_name: ""})
    end

    test "GTFS stores colours bare, CSS wants the hash" do
      assert %{color: "#FFC72C", text_color: "#000000"} =
               presented(%{route_color: "FFC72C", route_text_color: "000000"})
    end

    test "a colour that already has its hash keeps exactly one" do
      assert %{color: "#FFC72C"} = presented(%{route_color: "#FFC72C"})
    end

    test "no colour is no colour, not an empty one" do
      assert %{color: nil, text_color: nil} = presented(%{route_color: ""})
    end
  end

  test "the route carries its name and colour alongside its id" do
    [route] =
      PlusMQTT.condense_data({1, :gtfs}, [
        arrival(
          trip: %{
            trip_headsign: "Downtown",
            trip_short_name: "4021",
            bikes_allowed: 1,
            route_id: "r_9931",
            direction: %{direction: "Inbound"},
            route: route(%{route_short_name: "22", route_color: "FFC72C", route_id: "r_9931"})
          }
        )
      ])

    # The id is what anything downstream keys on, so it stays.
    assert route.route == "r_9931"
    assert route.route_name == "22"
    assert route.color == "#FFC72C"
    assert [%{name: "4021", bikes: 1}] = route.arrivals
  end

  describe "alerts" do
    # The alert lookup itself lives in room_gtfs, which room_sanctum does not
    # depend on -- the two only meet in the release -- so what is covered here
    # is the two guards that decide whether to reach for it at all.
    test "an id of nil is a preview with no worker to ask" do
      [route] = PlusMQTT.condense_data({nil, :gtfs}, [arrival(stop_id: "s1")])

      refute Map.has_key?(route, :alerts)
    end

    test "arrivals with no stop are not asked about alerts" do
      [route] = PlusMQTT.condense_data({1, :gtfs}, [arrival([])])

      refute Map.has_key?(route, :alerts)
    end
  end

  test "a type with no extended read falls back to Basic" do
    data = [%{name: "somewhere", period: nil}]

    assert PlusMQTT.condense_data({1, :cronos}, data) ==
             RoomSanctum.Condenser.BasicMQTT.condense_data({1, :cronos}, data)
  end

  test "nothing to condense is nothing" do
    assert PlusMQTT.condense_data({1, :gtfs}, []) == %{}
  end
end
