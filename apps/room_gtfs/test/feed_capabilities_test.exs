defmodule RoomGtfs.FeedCapabilitiesTest do
  @moduledoc """
  What a realtime feed actually fills in.

  Everything past a trip id and a time is optional in GTFS-RT, and a feed says
  nothing about which parts it bothers with. Two agencies both "support
  GTFS-RT" and share almost no optional fields.
  """
  use ExUnit.Case, async: true

  alias RoomGtfs.FeedTester
  alias TransitRealtime, as: T

  defp feed(entities) do
    %T.FeedMessage{header: %T.FeedHeader{gtfs_realtime_version: "2.0"}, entity: entities}
  end

  defp vehicle(attrs) do
    %T.FeedEntity{
      id: "e",
      vehicle: struct(%T.VehiclePosition{trip: %T.TripDescriptor{trip_id: "t1"}}, attrs)
    }
  end

  defp trip_update(stus, trip_attrs \\ []) do
    %T.FeedEntity{
      id: "e",
      trip_update: %T.TripUpdate{
        trip: struct(%T.TripDescriptor{trip_id: "t1"}, trip_attrs),
        stop_time_update: stus
      }
    }
  end

  defp stu(attrs) do
    struct(%T.TripUpdate.StopTimeUpdate{stop_id: "s1", schedule_relationship: :SCHEDULED}, attrs)
  end

  describe "vehicle positions" do
    test "a field the feed fills in is counted" do
      caps =
        FeedTester.capabilities(
          feed([
            vehicle(occupancy_status: :FULL),
            vehicle(occupancy_status: :EMPTY),
            vehicle(occupancy_status: nil)
          ])
        )

      assert caps["occupancy"] == %{present: 2, of: 3}
    end

    test "a field nothing reports is still listed, at zero" do
      caps = FeedTester.capabilities(feed([vehicle(occupancy_status: :FULL)]))

      # The answer worth having: this feed does not do congestion.
      assert caps["congestion level"] == %{present: 0, of: 1}
    end

    test "NO_DATA_AVAILABLE is the feed declining, not reporting" do
      caps = FeedTester.capabilities(feed([vehicle(occupancy_status: :NO_DATA_AVAILABLE)]))

      assert caps["occupancy"] == %{present: 0, of: 1}
    end

    test "-1 is the occupancy percentage default, not a percentage" do
      caps =
        FeedTester.capabilities(
          feed([vehicle(occupancy_percentage: -1), vehicle(occupancy_percentage: 40)])
        )

      assert caps["occupancy %"] == %{present: 1, of: 2}
    end

    test "carriages are counted as carriages, not as vehicles" do
      car = fn status ->
        %T.VehiclePosition.CarriageDetails{carriage_sequence: 1, occupancy_status: status}
      end

      caps =
        FeedTester.capabilities(
          feed([
            vehicle(multi_carriage_details: [car.(:EMPTY), car.(:NO_DATA_AVAILABLE)]),
            vehicle(multi_carriage_details: [])
          ])
        )

      assert caps["per-carriage occupancy"] == %{present: 1, of: 2}
      assert caps["carriage occupancy"] == %{present: 1, of: 2}
    end

    test "a bearing is counted against the vehicles, not the positions" do
      pos = %T.Position{latitude: 1.0, longitude: 2.0}

      caps =
        FeedTester.capabilities(
          feed([
            vehicle(position: %{pos | bearing: 90.0}),
            vehicle(position: pos),
            vehicle(position: nil)
          ])
        )

      assert caps["position"] == %{present: 2, of: 3}
      assert caps["bearing"] == %{present: 1, of: 3}
    end
  end

  describe "trip updates" do
    test "skipped stops are counted over stops, cancellations over trips" do
      caps =
        FeedTester.capabilities(
          feed([
            trip_update([stu(schedule_relationship: :SKIPPED), stu([])],
              schedule_relationship: :SCHEDULED
            ),
            trip_update([stu([])], schedule_relationship: :CANCELED)
          ])
        )

      assert caps["skipped stops"] == %{present: 1, of: 3}
      assert caps["cancelled / added trips"] == %{present: 1, of: 2}
    end

    test "a trip saying nothing about its relationship is running as published" do
      caps = FeedTester.capabilities(feed([trip_update([stu([])], schedule_relationship: nil)]))

      assert caps["cancelled / added trips"] == %{present: 0, of: 1}
    end

    test "delay and uncertainty are counted over the time events" do
      with_delay = stu(arrival: %T.TripUpdate.StopTimeEvent{time: 1, delay: 60})
      with_unc = stu(departure: %T.TripUpdate.StopTimeEvent{time: 1, uncertainty: 30})
      bare = stu(arrival: %T.TripUpdate.StopTimeEvent{time: 1})

      caps = FeedTester.capabilities(feed([trip_update([with_delay, with_unc, bare])]))

      assert caps["delay"] == %{present: 1, of: 3}
      assert caps["uncertainty"] == %{present: 1, of: 3}
    end

    test "a track assignment and a per-stop headsign" do
      props = %T.TripUpdate.StopTimeUpdate.StopTimeProperties{
        assigned_stop_id: "127N",
        stop_headsign: ""
      }

      caps =
        FeedTester.capabilities(
          feed([trip_update([stu(stop_time_properties: props), stu([])])])
        )

      assert caps["track assignment"] == %{present: 1, of: 2}
      # An empty string is not a headsign.
      assert caps["per-stop headsign"] == %{present: 0, of: 2}
    end
  end

  describe "alerts" do
    defp translated(text), do: %T.TranslatedString{translation: [%T.TranslatedString.Translation{text: text, language: "en"}]}

    defp alert(attrs) do
      %T.FeedEntity{id: "e", alert: struct(%T.Alert{}, attrs)}
    end

    defp selector(attrs), do: struct(%T.EntitySelector{}, attrs)

    test "a headline the publisher actually filled in" do
      caps =
        FeedTester.capabilities(
          feed([
            alert(header_text: translated("Red Line delays")),
            alert(header_text: nil)
          ])
        )

      assert caps["alert headline"] == %{present: 1, of: 2}
    end

    test "an empty envelope is not a headline" do
      caps =
        FeedTester.capabilities(
          feed([
            alert(header_text: %T.TranslatedString{translation: []}),
            alert(header_text: translated("   "))
          ])
        )

      # A field wired up and never filled reads the same as one never wired up.
      assert caps["alert headline"] == %{present: 0, of: 2}
    end

    test "the proto defaults for cause, effect and severity mean nothing was said" do
      caps =
        FeedTester.capabilities(
          feed([
            alert(cause: :UNKNOWN_CAUSE, effect: :UNKNOWN_EFFECT, severity_level: :UNKNOWN_SEVERITY),
            alert(cause: :STRIKE, effect: :DETOUR, severity_level: :SEVERE)
          ])
        )

      assert caps["alert cause"] == %{present: 1, of: 2}
      assert caps["alert effect"] == %{present: 1, of: 2}
      assert caps["alert severity"] == %{present: 1, of: 2}
    end

    test "periods, links and images" do
      caps =
        FeedTester.capabilities(
          feed([
            alert(
              active_period: [%T.TimeRange{start: 1}],
              url: translated("https://example.test/a"),
              image: %T.TranslatedImage{localized_image: []}
            ),
            alert([])
          ])
        )

      assert caps["alert period"] == %{present: 1, of: 2}
      assert caps["alert link"] == %{present: 1, of: 2}
      assert caps["alert image"] == %{present: 1, of: 2}
    end

    test "what an alert is aimed at, counted over the things it names" do
      caps =
        FeedTester.capabilities(
          feed([
            alert(
              informed_entity: [
                selector(stop_id: "s1", route_id: "Red"),
                selector(route_id: "Orange"),
                selector(trip: %T.TripDescriptor{trip_id: "t1"}),
                selector(agency_id: "1")
              ]
            )
          ])
        )

      assert caps["targets stops"] == %{present: 1, of: 4}
      assert caps["targets routes"] == %{present: 2, of: 4}
      assert caps["targets trips"] == %{present: 1, of: 4}
      # Naming an agency and nothing else is an alert about everything.
      assert caps["agency-wide"] == %{present: 1, of: 4}
    end

    test "a selector naming nothing at all is agency-wide too" do
      caps = FeedTester.capabilities(feed([alert(informed_entity: [selector([])])]))

      assert caps["agency-wide"] == %{present: 1, of: 1}
    end

    test "an alert naming nothing is not asked what it targets" do
      caps = FeedTester.capabilities(feed([alert(header_text: translated("x"))]))

      assert Map.has_key?(caps, "alert headline")
      refute Map.has_key?(caps, "targets stops")
    end
  end

  describe "what is not there" do
    test "a feed with no alerts says nothing about alerts" do
      caps = FeedTester.capabilities(feed([trip_update([stu([])])]))

      refute Map.has_key?(caps, "alert headline")
    end

    test "a feed with no vehicles says nothing about vehicles" do
      caps = FeedTester.capabilities(feed([trip_update([stu([])])]))

      # Rather than 0 of 0 everywhere, which would read as a feed refusing to
      # give them.
      refute Map.has_key?(caps, "occupancy")
      refute Map.has_key?(caps, "congestion level")
      assert Map.has_key?(caps, "skipped stops")
    end

    test "an empty feed reports nothing at all" do
      assert FeedTester.capabilities(feed([])) == %{}
    end
  end
end
