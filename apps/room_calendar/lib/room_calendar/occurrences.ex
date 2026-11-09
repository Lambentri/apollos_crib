defmodule RoomCalendar.Occurrences do
  @moduledoc """
  A feed's events as the dates they actually happen on.

  A repeating event is one VEVENT with an RRULE, not one per date, so storing
  events as they come stores the first date and nothing after. This expands
  each rule over a window, in the event's own zone -- 7pm every third Monday
  stays 7pm across the clock change -- and settles the two ways a feed edits
  one date of a series:

    * EXDATE on the series drops a date; the rule expansion applies it.
    * A second VEVENT with the series' UID and a RECURRENCE-ID replaces the
      date it names, moved, retitled or cancelled. Google writes most edits
      this way, so the generated date it replaces is dropped here and the
      override stands in its place.

  Cancelled events, and cancelled overrides with them, are left out.
  """

  # A runaway rule -- one that matches nothing, or matches every second --
  # stops here rather than taking the worker with it.
  @max_per_rule 2_000

  @type t :: %{
          start: DateTime.t(),
          end: DateTime.t() | nil,
          all_day: boolean,
          summary: String.t() | nil,
          description: String.t() | nil,
          location: String.t() | nil,
          uid: String.t() | nil,
          rrule: map | nil
        }

  @doc """
  Every occurrence of `events` overlapping `from`..`to`, soonest first, with
  start and end in UTC. All-day occurrences start at midnight UTC on their
  date, which is how the rest of the app reads a whole day.
  """
  @spec expand([ICal.Event.t()], DateTime.t(), DateTime.t()) :: [t()]
  def expand(events, from, to) do
    replaced =
      events
      |> Enum.filter(& &1.recurrence_id)
      |> MapSet.new(&{&1.uid, instant(&1.recurrence_id)})

    events
    |> Enum.filter(& &1.dtstart)
    |> Enum.flat_map(fn e ->
      if e.rrule && is_nil(e.recurrence_id) do
        e
        |> ICal.Recurrence.stream()
        |> Stream.take(@max_per_rule)
        |> Stream.take_while(&(DateTime.compare(instant(&1), to) == :lt))
        |> Stream.reject(&MapSet.member?(replaced, {e.uid, instant(&1)}))
        |> Enum.map(&occurrence(e, &1))
      else
        [occurrence(e, e.dtstart)]
      end
    end)
    |> Enum.reject(&(&1.status == :cancelled))
    |> Enum.filter(&overlaps?(&1, from, to))
    |> Enum.sort_by(& &1.start, DateTime)
    |> Enum.map(&Map.delete(&1, :status))
  end

  defp occurrence(e, start) do
    {s, f, all_day} = span(e, start)

    %{
      start: s,
      end: f,
      all_day: all_day,
      summary: e.summary,
      description: e.description,
      location: e.location,
      uid: e.uid,
      status: e.status,
      # The series' rule, on every date it made. An override is a date of a
      # series too, though it carries no rule of its own.
      rrule: rule(e)
    }
  end

  # An occurrence lasts as long as the event it came from: DTEND less DTSTART,
  # or DURATION, or -- with neither -- a whole day for a date, and no length
  # at all for a time.
  defp span(e, %Date{} = day) do
    days =
      cond do
        match?(%Date{}, e.dtend) -> max(Date.diff(e.dtend, e.dtstart), 1)
        e.duration -> max(div(seconds(e.duration), 86_400), 1)
        true -> 1
      end

    s = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
    {s, DateTime.add(s, days, :day), true}
  end

  defp span(e, start) do
    s = instant(start)

    f =
      cond do
        e.dtend -> DateTime.add(s, DateTime.diff(instant(e.dtend), instant(e.dtstart)))
        e.duration -> DateTime.add(s, seconds(e.duration))
        true -> nil
      end

    {s, f, false}
  end

  defp overlaps?(%{start: s, end: f}, from, to) do
    DateTime.compare(s, to) == :lt and DateTime.compare(f || s, from) != :lt
  end

  # Floating times name no zone; read as UTC, as the old parser did.
  defp instant(%DateTime{} = dt), do: DateTime.shift_zone!(dt, "Etc/UTC")
  defp instant(%NaiveDateTime{} = dt), do: DateTime.from_naive!(dt, "Etc/UTC")
  defp instant(%Date{} = d), do: DateTime.new!(d, ~T[00:00:00], "Etc/UTC")

  defp seconds(%ICal.Duration{positive: pos, weeks: w, days: d, time: {h, m, s}}) do
    total = ((w * 7 + d) * 24 + h) * 3600 + m * 60 + s
    if pos, do: total, else: -total
  end

  # Enough to say that it repeats and how often; the rule itself has done its
  # work by the time anything is stored.
  defp rule(%{rrule: %ICal.Recurrence{frequency: freq, interval: interval}}),
    do: %{"freq" => Atom.to_string(freq), "interval" => interval}

  defp rule(%{recurrence_id: rid}) when not is_nil(rid), do: %{"override" => true}
  defp rule(_), do: nil
end
