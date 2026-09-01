defmodule RoomSanctum.ArrivalServiceDayTest do
  @moduledoc """
  The arrival query keeps only trips whose service runs today -- and knows when
  it is not entitled to an opinion.

  A stop's timetable holds every service pattern the feed publishes. On the
  MBTA bus feed in the dev database one stop mixed twelve, and 80% of an hour's
  arrivals were departures that will not happen. Filtering them is most of what
  makes a board correct.

  The two escapes matter as much as the filter. Two of eight sources there have
  no usable service data at all -- one with 33,163 trips and not a single
  calendar row -- and a filter without them would show those sources nothing.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Accounts, Configuration, Repo, Storage}
  alias RoomSanctum.Storage.GTFS.{Calendar, CalendarDate, StopTime, Trip}

  # 2026-09-01 is a Tuesday.
  @today ~D[2026-09-01]
  @at DateTime.new!(~D[2026-09-01], ~T[08:00:00], "Etc/UTC")

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "sd#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "T", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "Etc/UTC"}
      })

    %{source: source}
  end

  defp calendar(source, service_id, days, range \\ {~D[2026-08-31], ~D[2026-09-05]}) do
    {start_date, end_date} = range

    attrs =
      %{source_id: source.id, service_id: service_id, start_date: start_date, end_date: end_date}
      |> Map.merge(Map.new(~w(monday tuesday wednesday thursday friday saturday sunday)a, &{&1, 0}))
      |> Map.merge(Map.new(days, &{&1, 1}))

    Repo.insert!(Calendar.changeset(%Calendar{}, attrs))
  end

  defp exception(source, service_id, type) do
    Repo.insert!(
      CalendarDate.changeset(%CalendarDate{}, %{
        source_id: source.id, service_id: service_id, date: @today, exception_type: type
      })
    )
  end

  # One trip on a service, calling at "s1" at 08:30.
  defp trip_calling(source, service_id) do
    trip_id = "trip-#{service_id}-#{System.unique_integer([:positive])}"

    Repo.insert!(%Trip{
      source_id: source.id, trip_id: trip_id, route_id: "r1",
      service_id: service_id, direction_id: 0, trip_headsign: "Downtown"
    })

    Repo.insert!(%StopTime{
      source_id: source.id, trip_id: trip_id, stop_id: "s1", stop_sequence: 1,
      arrival_time: %Postgrex.Interval{secs: 8 * 3600 + 1800},
      departure_time: %Postgrex.Interval{secs: 8 * 3600 + 1800}
    })

    trip_id
  end

  defp arrivals(source) do
    Storage.get_upcoming_arrivals_for_stop(source.id, "s1", 50, @at, "Etc/UTC")
    |> Enum.map(& &1.trip_id)
  end

  test "a service running today is kept", %{source: source} do
    calendar(source, "weekday", [:tuesday])
    trip = trip_calling(source, "weekday")

    assert arrivals(source) == [trip]
  end

  test "a service for another day is dropped", %{source: source} do
    calendar(source, "weekday", [:tuesday])
    calendar(source, "saturday", [:saturday])
    keep = trip_calling(source, "weekday")
    _drop = trip_calling(source, "saturday")

    assert arrivals(source) == [keep]
  end

  test "a service whose date range has passed is dropped", %{source: source} do
    calendar(source, "weekday", [:tuesday])
    calendar(source, "expired", [:tuesday], {~D[2026-07-01], ~D[2026-08-28]})
    keep = trip_calling(source, "weekday")
    _drop = trip_calling(source, "expired")

    assert arrivals(source) == [keep]
  end

  test "a service added for today by exception is kept", %{source: source} do
    calendar(source, "weekday", [:tuesday])
    # Every weekday flag zero -- the MBTA shape, which runs only by exception.
    calendar(source, "by-exception", [], {@today, @today})
    exception(source, "by-exception", 1)

    keep = trip_calling(source, "weekday")
    also = trip_calling(source, "by-exception")

    assert Enum.sort(arrivals(source)) == Enum.sort([keep, also])
  end

  test "a service removed for today by exception is dropped", %{source: source} do
    calendar(source, "weekday", [:tuesday])
    calendar(source, "holiday", [:tuesday])
    exception(source, "holiday", 2)

    keep = trip_calling(source, "weekday")
    _drop = trip_calling(source, "holiday")

    assert arrivals(source) == [keep]
  end

  describe "the escapes" do
    test "a service nothing says anything about is kept", %{source: source} do
      calendar(source, "weekday", [:tuesday])
      keep = trip_calling(source, "weekday")
      # No calendar row, no exception: we have not been told when this runs, so
      # hiding it would assert something we do not know.
      unknown = trip_calling(source, "no-info")

      assert Enum.sort(arrivals(source)) == Enum.sort([keep, unknown])
    end

    test "a source with nothing running today is not filtered at all", %{source: source} do
      # Stale service data -- the state two of eight dev sources are actually in.
      calendar(source, "expired-a", [:tuesday], {~D[2026-07-01], ~D[2026-08-28]})
      calendar(source, "expired-b", [:saturday], {~D[2026-07-01], ~D[2026-08-28]})

      a = trip_calling(source, "expired-a")
      b = trip_calling(source, "expired-b")

      # A board of possibly-wrong times beats a blank one.
      assert Enum.sort(arrivals(source)) == Enum.sort([a, b])
    end

    test "one service running today is enough to switch filtering on", %{source: source} do
      calendar(source, "weekday", [:tuesday])
      calendar(source, "saturday", [:saturday])

      keep = trip_calling(source, "weekday")
      _drop = trip_calling(source, "saturday")

      assert arrivals(source) == [keep]
    end

    test "an exception alone is enough to switch filtering on", %{source: source} do
      calendar(source, "saturday", [:saturday])
      exception(source, "added", 1)

      added = trip_calling(source, "added")
      _drop = trip_calling(source, "saturday")

      assert arrivals(source) == [added]
    end
  end
end
