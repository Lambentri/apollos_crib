defmodule RoomCalendar.OccurrencesTest do
  @moduledoc """
  A feed in the shape Google writes one: a monthly series on an ordinal
  weekday, one date dropped by EXDATE, one moved by an override, one cancelled
  by an override, and an all-day event beside them.
  """
  use ExUnit.Case, async: true

  alias RoomCalendar.Occurrences

  @ics """
  BEGIN:VCALENDAR
  VERSION:2.0
  BEGIN:VEVENT
  UID:laser@example
  SUMMARY:CO2 Laser Training
  DTSTART;TZID=America/New_York:20260921T190000
  DTEND;TZID=America/New_York:20260921T210000
  RRULE:FREQ=MONTHLY;BYDAY=3MO
  EXDATE;TZID=America/New_York:20261221T190000
  END:VEVENT
  BEGIN:VEVENT
  UID:laser@example
  RECURRENCE-ID;TZID=America/New_York:20261116T190000
  SUMMARY:CO2 Laser Training (moved)
  DTSTART;TZID=America/New_York:20261117T180000
  DTEND;TZID=America/New_York:20261117T200000
  END:VEVENT
  BEGIN:VEVENT
  UID:laser@example
  RECURRENCE-ID;TZID=America/New_York:20270118T190000
  STATUS:CANCELLED
  SUMMARY:CO2 Laser Training
  DTSTART;TZID=America/New_York:20270118T190000
  DTEND;TZID=America/New_York:20270118T210000
  END:VEVENT
  BEGIN:VEVENT
  UID:hack@example
  SUMMARY:Hack the Space
  DTSTART;VALUE=DATE:20261031
  DTEND;VALUE=DATE:20261101
  RRULE:FREQ=MONTHLY;BYDAY=-1SA;COUNT=3
  END:VEVENT
  BEGIN:VEVENT
  UID:once@example
  SUMMARY:Long ago
  DTSTART:20200101T120000Z
  DTEND:20200101T130000Z
  END:VEVENT
  END:VCALENDAR
  """

  defp expand(from \\ ~U[2026-10-01 00:00:00Z], to \\ ~U[2027-03-01 00:00:00Z]) do
    @ics |> ICal.from_ics() |> Map.fetch!(:events) |> Occurrences.expand(from, to)
  end

  defp starts(summary_prefix) do
    expand()
    |> Enum.filter(&String.starts_with?(&1.summary, summary_prefix))
    |> Enum.map(& &1.start)
  end

  test "an ordinal-weekday series is written out, 7pm local across the clock change" do
    # Oct is EDT (UTC-4), Feb is EST (UTC-5): the same 19:00 in New York.
    assert ~U[2026-10-19 23:00:00Z] in starts("CO2")
    assert ~U[2027-02-16 00:00:00Z] in starts("CO2")
  end

  test "EXDATE drops its date, an override replaces its, a cancelled override removes its" do
    laser = expand() |> Enum.filter(&(&1.uid == "laser@example"))

    assert Enum.map(laser, &{&1.summary, &1.start}) == [
             {"CO2 Laser Training", ~U[2026-10-19 23:00:00Z]},
             # 16 Nov moved to the 17th at 6pm EST.
             {"CO2 Laser Training (moved)", ~U[2026-11-17 23:00:00Z]},
             # 21 Dec excluded; 18 Jan cancelled.
             {"CO2 Laser Training", ~U[2027-02-16 00:00:00Z]}
           ]
  end

  test "each date keeps the event's length, and says which series it came from" do
    [first | _] = expand()

    assert first.end == DateTime.add(first.start, 2, :hour)
    assert first.rrule == %{"freq" => "monthly", "interval" => 1}
    refute first.all_day
  end

  test "an override is a date of a series though it carries no rule" do
    assert %{rrule: %{"override" => true}} = Enum.find(expand(), &(&1.summary =~ "moved"))
  end

  test "all-day dates are midnight UTC to midnight UTC, flagged, and honour COUNT" do
    hack = expand() |> Enum.filter(&(&1.summary == "Hack the Space"))

    assert Enum.map(hack, & &1.start) ==
             [~U[2026-10-31 00:00:00Z], ~U[2026-11-28 00:00:00Z], ~U[2026-12-26 00:00:00Z]]

    assert Enum.all?(hack, &(&1.all_day and &1.end == DateTime.add(&1.start, 1, :day)))
  end

  test "only what overlaps the window, soonest first" do
    all = expand()

    refute Enum.any?(all, &(&1.summary == "Long ago"))
    assert all == Enum.sort_by(all, & &1.start, DateTime)
  end
end
