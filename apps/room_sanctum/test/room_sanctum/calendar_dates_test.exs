defmodule RoomSanctum.CalendarDatesTest do
  @moduledoc """
  calendar_dates.txt, and the service-day answer that needs it.

  For several feeds this is not a footnote to calendar.txt. MBTA's bus feed
  carries services whose seven weekday flags are all zero and whose date range
  is a single day -- every day they run is named in calendar_dates instead --
  so a filter reading only calendar.txt drops trips that are genuinely running.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Accounts, Configuration, Repo, Storage}
  alias RoomSanctum.Storage.GTFS.{Calendar, CalendarDate}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "cd#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "T", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"}
      })

    %{source: source}
  end

  defp calendar(source, service_id, days, start_date, end_date) do
    attrs =
      %{source_id: source.id, service_id: service_id, start_date: start_date, end_date: end_date}
      |> Map.merge(Map.new(~w(monday tuesday wednesday thursday friday saturday sunday)a, &{&1, 0}))
      |> Map.merge(Map.new(days, &{&1, 1}))

    Repo.insert!(Calendar.changeset(%Calendar{}, attrs))
  end

  defp exception(source, service_id, date, type) do
    Repo.insert!(
      CalendarDate.changeset(%CalendarDate{}, %{
        source_id: source.id, service_id: service_id, date: date, exception_type: type
      })
    )
  end

  describe "the date format" do
    test "GTFS writes YYYYMMDD, which Ecto's date cast rejects on its own" do
      cs = CalendarDate.changeset(%CalendarDate{}, %{service_id: "s", date: "20260901", exception_type: 1})

      assert cs.valid?
      assert get_change(cs, :date) == ~D[2026-09-01]
    end

    test "an already-dashed date is left alone" do
      cs = CalendarDate.changeset(%CalendarDate{}, %{service_id: "s", date: "2026-09-01", exception_type: 1})

      assert get_change(cs, :date) == ~D[2026-09-01]
    end

    test "eight characters that are not a date do not become one" do
      cs = CalendarDate.changeset(%CalendarDate{}, %{service_id: "s", date: "not-adat", exception_type: 1})

      refute cs.valid?
    end

    test "only 1 and 2 are exception types" do
      for t <- [1, 2] do
        assert CalendarDate.changeset(%CalendarDate{}, %{service_id: "s", date: "20260901", exception_type: t}).valid?
      end

      refute CalendarDate.changeset(%CalendarDate{}, %{service_id: "s", date: "20260901", exception_type: 3}).valid?
    end
  end

  describe "count_trips_without_service/1" do
    alias RoomSanctum.Storage.GTFS.Trip

    defp trip(source, service_id) do
      Repo.insert!(%Trip{
        source_id: source.id,
        trip_id: "t-#{service_id}-#{System.unique_integer([:positive])}",
        route_id: "r1",
        service_id: service_id
      })
    end

    test "counts the trips the arrival filter has to keep on faith", %{source: source} do
      calendar(source, "known", [:tuesday], ~D[2026-08-31], ~D[2026-09-05])
      trip(source, "known")
      trip(source, "orphan-a")
      trip(source, "orphan-b")

      assert Storage.count_trips_without_service(source.id) == 2
    end

    test "an exception counts as knowing, even with no calendar row", %{source: source} do
      exception(source, "by-exception", ~D[2026-09-01], 1)
      trip(source, "by-exception")

      assert Storage.count_trips_without_service(source.id) == 0
    end

    test "another source's trips are not counted", %{source: source} do
      {:ok, other_user} =
        Accounts.register_user(%{
          email: "cnt#{System.unique_integer([:positive])}@example.com",
          password: "hello world!hello world!"
        })

      {:ok, other} =
        Configuration.create_source(%{
          name: "U", notes: "", type: :gtfs, enabled: true, user_id: other_user.id,
          config: %{"__type__" => "gtfs", "url" => "https://e.test/u.zip", "tz" => "UTC"}
        })

      trip(other, "theirs")

      assert Storage.count_trips_without_service(source.id) == 0
    end
  end

  describe "services_on/2" do
    test "a service whose weekday flag is set, inside its date range", %{source: source} do
      # 2026-09-01 is a Tuesday.
      calendar(source, "weekday", [:tuesday], ~D[2026-08-31], ~D[2026-09-04])

      assert MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "weekday")
    end

    test "the same service outside its date range does not run", %{source: source} do
      calendar(source, "expired", [:tuesday], ~D[2026-07-01], ~D[2026-08-28])

      refute MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "expired")
    end

    test "the wrong weekday does not run", %{source: source} do
      calendar(source, "saturday", [:saturday], ~D[2026-08-31], ~D[2026-09-04])

      refute MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "saturday")
    end

    test "a service defined only by exception runs -- the case that needed this", %{source: source} do
      # Every weekday flag zero, a single-day range: MBTA's shape exactly.
      calendar(source, "by-exception", [], ~D[2026-09-01], ~D[2026-09-01])
      exception(source, "by-exception", ~D[2026-09-01], 1)

      assert MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "by-exception")
    end

    test "an added service needs no calendar row at all", %{source: source} do
      exception(source, "orphan", ~D[2026-09-01], 1)

      assert MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "orphan")
    end

    test "a removal beats the weekday flag", %{source: source} do
      calendar(source, "holiday", [:tuesday], ~D[2026-08-31], ~D[2026-09-04])
      exception(source, "holiday", ~D[2026-09-01], 2)

      refute MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "holiday")
    end

    test "exceptions apply to their own date only", %{source: source} do
      exception(source, "one-day", ~D[2026-09-01], 1)

      assert MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "one-day")
      refute MapSet.member?(Storage.services_on(source.id, ~D[2026-09-02]), "one-day")
    end

    test "another source's services are not this source's", %{source: source} do
      {:ok, other_user} =
        Accounts.register_user(%{
          email: "cd2#{System.unique_integer([:positive])}@example.com",
          password: "hello world!hello world!"
        })

      {:ok, other} =
        Configuration.create_source(%{
          name: "U", notes: "", type: :gtfs, enabled: true, user_id: other_user.id,
          config: %{"__type__" => "gtfs", "url" => "https://e.test/u.zip", "tz" => "UTC"}
        })

      exception(other, "theirs", ~D[2026-09-01], 1)

      refute MapSet.member?(Storage.services_on(source.id, ~D[2026-09-01]), "theirs")
    end

    test "a source with nothing loaded runs nothing", %{source: source} do
      assert Storage.services_on(source.id, ~D[2026-09-01]) == MapSet.new()
    end
  end
end
