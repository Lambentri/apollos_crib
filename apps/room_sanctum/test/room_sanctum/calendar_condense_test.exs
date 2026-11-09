defmodule RoomSanctum.CalendarCondenseTest do
  @moduledoc """
  Which day a calendar entry falls on, and what each condenser says of it.

  Entries are stored on two clocks -- all-day ones at midnight UTC, timed ones
  at their real instant -- so the day has to be worked out per entry, at the
  query's foci. Boston, where midnight UTC is the evening before and 9pm is
  already tomorrow in UTC.
  """
  use RoomSanctum.DataCase, async: true

  alias RoomSanctum.{Accounts, Configuration, Storage}
  alias RoomSanctum.Condenser.{BasicMQTT, PlusMQTT}

  @tz "America/New_York"

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "cal#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Bins", notes: "", type: :calendar, enabled: true, user_id: user.id,
        config: %{"__type__" => "calendar", "url" => "http://127.0.0.1:9/cal.ics"}
      })

    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home", user_id: user.id,
        place: %Geo.Point{coordinates: {-71.0589, 42.3601}, srid: 4326}
      })

    today = @tz |> DateTime.now!() |> DateTime.to_date()
    %{source: source, foci: foci, today: today}
  end

  defp all_day(source, summary, day, days \\ 1) do
    start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
    store(source, summary, start, DateTime.add(start, days, :day))
  end

  defp at(source, summary, day, time, blob \\ %{}) do
    start = day |> DateTime.new!(time, @tz) |> DateTime.shift_zone!("Etc/UTC")
    store(source, summary, start, DateTime.add(start, 1, :hour), blob)
  end

  defp store(source, summary, start, finish, blob \\ %{}) do
    {:ok, e} =
      Storage.create_icalendar(%{
        source_id: source.id, date_start: start, date_end: finish,
        blob: Map.merge(%{"summary" => summary, "description" => "about #{summary}"}, blob)
      })

    e
  end

  defp upcoming(ctx, days \\ 3, limit \\ 10),
    do: Storage.get_upcoming_calendar_entries(ctx.source.id, %{foci_id: ctx.foci.id, days: days, limit: limit})

  describe "the window" do
    test "today's all-day entry stays in, though its midnight UTC was last evening here", ctx do
      all_day(ctx.source, "Bins", ctx.today)
      all_day(ctx.source, "Yesterday's bins", Date.add(ctx.today, -1))

      assert ["Bins"] = upcoming(ctx) |> Enum.map(& &1.blob["summary"])
    end

    test "runs today through days - 1, by the local day of each entry", ctx do
      all_day(ctx.source, "Last day", Date.add(ctx.today, 2))
      all_day(ctx.source, "Past the end", Date.add(ctx.today, 3))
      at(ctx.source, "Evening", ctx.today, ~T[21:00:00])
      all_day(ctx.source, "Bins", ctx.today)

      assert ["Bins", "Evening", "Last day"] = upcoming(ctx) |> Enum.map(& &1.blob["summary"])
    end

    test "the limit is taken after the entries are in order", ctx do
      at(ctx.source, "Evening", ctx.today, ~T[21:00:00])
      all_day(ctx.source, "Bins", Date.add(ctx.today, 1))

      assert ["Evening"] = upcoming(ctx, 3, 1) |> Enum.map(& &1.blob["summary"])
    end
  end

  describe "Basic" do
    test "a 9pm entry is on its own day, not on UTC's", ctx do
      at(ctx.source, "Evening", ctx.today, ~T[21:00:00])

      assert [%{date_start: day, summary: "Evening", description: "about Evening"}] =
               BasicMQTT.condense_data({1, :calendar}, upcoming(ctx))

      assert day == ctx.today
    end
  end

  describe "Plus" do
    test "is Basic's entry and the rest of the event", ctx do
      at(ctx.source, "Meeting", ctx.today, ~T[21:00:00], %{"location" => "Hall", "rrule" => %{"freq" => "WEEKLY"}})
      all_day(ctx.source, "Festival", Date.add(ctx.today, 1), 3)

      entries = upcoming(ctx)
      [meeting, festival] = PlusMQTT.condense_data({1, :calendar}, entries)

      # Everything Basic says, unchanged.
      assert Enum.map([meeting, festival], &Map.take(&1, [:date_start, :summary, :description])) ==
               BasicMQTT.condense_data({1, :calendar}, entries)

      assert %{all_day: false, location: "Hall", repeats: true, tz: @tz} = meeting
      assert meeting.start.time_zone == @tz
      assert {DateTime.to_date(meeting.start), DateTime.to_time(meeting.start)} == {ctx.today, ~T[21:00:00]}
      assert DateTime.to_time(meeting.end) == ~T[22:00:00]

      assert %{all_day: true, location: nil, repeats: false} = festival
      assert festival.start == Date.add(ctx.today, 1)
      # DTEND is the day after; the last day is inclusive.
      assert festival.end == Date.add(ctx.today, 3)
    end

    test "the wrapped board carries Plus's entry, not Basic's", ctx do
      at(ctx.source, "Meeting", ctx.today, ~T[21:00:00])

      assert %{data: [%{all_day: false}], query: %{name: "Bins"}} =
               PlusMQTT.condense({1, :calendar}, upcoming(ctx), %{name: "Bins", meta: nil})
    end
  end

  describe "all_day?" do
    alias RoomSanctum.Storage.ICalendar

    test "a row's own flag beats the midnight guess, either way" do
      midnight = %{date_start: ~U[2026-11-02 00:00:00Z], date_end: ~U[2026-11-02 02:00:00Z]}
      day = %{date_start: ~U[2026-11-02 00:00:00Z], date_end: ~U[2026-11-03 00:00:00Z]}

      # 8pm Eastern for two hours, written by the feed as a time.
      refute ICalendar.all_day?(Map.put(day, :blob, %{"all_day" => false}))
      assert ICalendar.all_day?(Map.put(midnight, :blob, %{"all_day" => true}))
      # Rows from before the flag still get the guess.
      assert ICalendar.all_day?(Map.put(day, :blob, %{}))
    end
  end
end
