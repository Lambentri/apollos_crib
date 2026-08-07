defmodule RoomCronos.Countdown do
  @moduledoc """
  Time remaining until, or elapsed since, a fixed point.

  The target is a wall-clock time local to the query's Foci, not an instant --
  "midnight on the 25th" means midnight where you are, and stays midnight across
  a DST boundary.

  With `annual?` set, the target is treated as a recurring date: once this year's
  occurrence passes, it immediately re-targets next year's, so a birthday or
  anniversary flips straight back to counting down instead of counting up
  forever.
  """

  @doc """
  Compute the countdown for `target` (a NaiveDateTime, local to `tz`) as of `now`.

  Returns a map with the signed second count, a broken-down duration, and enough
  context for the UI to say which direction it is going.
  """
  def compute(target, annual?, now, tz) do
    occurrence = occurrence_for(target, annual?, now, tz)

    case to_datetime(occurrence, tz) do
      nil ->
        nil

      target_dt ->
        seconds = DateTime.diff(target_dt, now, :second)

        %{
          target: occurrence,
          target_at: target_dt,
          annual: annual?,
          # Rolled means we are showing a later year than the date entered.
          rolled: occurrence.year != target.year,
          direction: if(seconds >= 0, do: :until, else: :since,
          ),
          seconds: seconds
        }
        |> Map.merge(breakdown(seconds))
    end
  end

  @doc "Split a signed second count into whole days, hours, minutes and seconds."
  def breakdown(seconds) do
    total = abs(seconds)

    %{
      days: div(total, 86_400),
      hours: total |> rem(86_400) |> div(3600),
      minutes: total |> rem(3600) |> div(60),
      secs: rem(total, 60)
    }
  end

  # Non-recurring targets are used as entered, however far in the past they are.
  defp occurrence_for(target, false, _now, _tz), do: target

  defp occurrence_for(target, true, now, tz) do
    this_year = shift_year(target, now.year)

    # Comparing in the target's own zone matters near midnight: an occurrence
    # that has passed in UTC may still be hours away locally.
    if past?(this_year, now, tz) do
      shift_year(target, now.year + 1)
    else
      this_year
    end
  end

  defp past?(occurrence, now, tz) do
    case to_datetime(occurrence, tz) do
      nil -> false
      dt -> DateTime.compare(dt, now) == :lt
    end
  end

  # Feb 29 only exists every fourth year, so a leap-day target clamps to the
  # 28th rather than vanishing for three years at a time.
  defp shift_year(%NaiveDateTime{} = target, year) do
    day = min(target.day, :calendar.last_day_of_the_month(year, target.month))

    %{target | year: year, day: day}
  end

  defp to_datetime(%NaiveDateTime{} = naive, tz) when is_binary(tz) do
    case DateTime.from_naive(naive, tz, Tzdata.TimeZoneDatabase) do
      {:ok, dt} -> dt
      # DST edges: pick a side deterministically rather than losing the target
      # on the two days a year it matters.
      {:ambiguous, first, _second} -> first
      {:gap, _before, just_after} -> just_after
      _ -> nil
    end
  end

  defp to_datetime(_, _), do: nil
end
