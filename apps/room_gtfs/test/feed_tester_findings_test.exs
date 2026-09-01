defmodule RoomGtfs.FeedTesterFindingsTest do
  @moduledoc """
  The two ways a realtime feed can be wrong without saying so.

  Both decode cleanly, report plausible numbers, and quietly match nothing --
  which is the failure this tester exists to name.
  """
  use ExUnit.Case, async: true

  alias RoomGtfs.FeedTester
  alias TransitRealtime, as: T

  defp feed(entities, header_attrs \\ []) do
    %T.FeedMessage{
      header: struct(%T.FeedHeader{gtfs_realtime_version: "2.0"}, header_attrs),
      entity: entities
    }
  end

  defp trip_update(stus, attrs \\ []) do
    struct(
      %T.FeedEntity{
        id: "e",
        trip_update: %T.TripUpdate{
          trip: %T.TripDescriptor{trip_id: "t1"},
          stop_time_update: stus
        }
      },
      attrs
    )
  end

  defp stu(attrs), do: struct(%T.TripUpdate.StopTimeUpdate{}, attrs)

  defp messages(result), do: Enum.map(result.findings, fn {_sev, m} -> m end) |> Enum.join(" | ")
  defp severities(result), do: Enum.map(result.findings, fn {sev, _m} -> sev end)

  # The checks run over a decoded feed; fetching it and comparing it to the
  # static schedule are separate concerns, so these are exercised on their own.
  defp check(feed) do
    %{findings: []}
    |> FeedTester.check_incrementality(feed)
    |> FeedTester.check_stop_identification(feed)
  end

  describe "differential feeds" do
    test "a full dataset says nothing about it" do
      result = check(feed([trip_update([stu(stop_id: "s1")])], incrementality: :FULL_DATASET))

      refute messages(result) =~ "DIFFERENTIAL"
    end

    test "a differential feed is handled, so it is a note rather than a fault" do
      result = check(feed([trip_update([stu(stop_id: "s1")])], incrementality: :DIFFERENTIAL))

      assert messages(result) =~ "differential"
      assert messages(result) =~ "held between polls"
      assert :info in severities(result)
      refute :error in severities(result)
    end

    test "it says the count on the page is a delta, not a total" do
      entities = [
        trip_update([stu(stop_id: "s1")], is_deleted: true),
        trip_update([stu(stop_id: "s1")])
      ]

      result = check(feed(entities, incrementality: :DIFFERENTIAL))

      assert messages(result) =~ "one of them a deletion"
      assert messages(result) =~ "not the whole feed"
    end

    test "deletions in a feed calling itself whole are still worth flagging" do
      entities = [trip_update([stu(stop_id: "s1")], is_deleted: true)]

      result = check(feed(entities, incrementality: :FULL_DATASET))

      assert messages(result) =~ "marked deleted"
      assert :warn in severities(result)
    end
  end

  describe "stops named only by position" do
    test "a feed carrying stop ids is fine" do
      result = check(feed([trip_update([stu(stop_id: "s1", stop_sequence: 4)])]))

      refute messages(result) =~ "position in the trip"
    end

    test "no stop ids anywhere is an error: nothing will ever match" do
      result = check(feed([trip_update([stu(stop_sequence: 4), stu(stop_sequence: 5)])]))

      assert messages(result) =~ "never by stop id"
      assert :error in severities(result)
    end

    test "some missing is a warning naming how many" do
      result = check(feed([trip_update([stu(stop_id: "s1"), stu(stop_sequence: 5)])]))

      assert messages(result) =~ "1 of 2 stop updates carry no stop id"
      assert :warn in severities(result)
    end

    test "an empty string is not a stop id" do
      result = check(feed([trip_update([stu(stop_id: "", stop_sequence: 5)])]))

      assert messages(result) =~ "never by stop id"
    end

    test "a feed with no trip updates is not asked about stops" do
      vehicle = %T.FeedEntity{id: "e", vehicle: %T.VehiclePosition{}}

      refute messages(check(feed([vehicle]))) =~ "position in the trip"
    end
  end
end
