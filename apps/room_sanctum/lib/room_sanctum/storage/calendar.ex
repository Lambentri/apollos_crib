defmodule RoomSanctum.Storage.ICalendar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icalendar_entries" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :date_start, :utc_datetime
    field :date_end, :utc_datetime
    field :blob, :map
    # The zone of the foci a query read the entry for, so a condenser can say
    # what day and hour it falls on there. Nil when nobody asked from a place.
    field :tz, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, [:blob, :source_id, :date_start, :date_end])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:blob, :date_start])
  end

  @doc """
  Whether an entry is a whole day rather than a time.

  Said by the row itself since the feed is read with `ical`, which keeps
  `VALUE=DATE` as a date. Rows stored before that carry no flag, and for them
  midnight UTC at both ends is all there is to go on -- a timed event that
  really does start and end on a UTC midnight reads as all-day.
  """
  def all_day?(%{blob: %{"all_day" => flag}}) when is_boolean(flag), do: flag
  def all_day?(%{date_start: s, date_end: e}), do: all_day?(s, e)

  def all_day?(%DateTime{} = s, e), do: utc_midnight?(s) and (is_nil(e) or utc_midnight?(e))
  def all_day?(_s, _e), do: false

  defp utc_midnight?(%DateTime{} = dt),
    do: dt |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_time() == ~T[00:00:00]

  @doc """
  The day an entry falls on where it was asked about.

  An all-day entry's date is its own and is never shifted: midnight UTC moved
  to New York is the evening before, and the bins are not out a day early. A
  timed one is converted first, so 9pm Eastern -- 01:00 UTC the next morning --
  stays on the day it happens.
  """
  def local_date(%{date_start: s} = entry) do
    if all_day?(entry), do: DateTime.to_date(s), else: s |> local(entry_tz(entry)) |> DateTime.to_date()
  end

  @doc """
  The last day an entry covers, inclusive. An all-day DTEND is the day after
  the event, so a one-day event ends where it starts.
  """
  def local_last_date(%{date_end: nil} = entry), do: local_date(entry)

  def local_last_date(%{date_end: e} = entry) do
    if all_day?(entry),
      do: e |> DateTime.to_date() |> Date.add(-1) |> max_date(local_date(entry)),
      else: e |> local(entry_tz(entry)) |> DateTime.to_date()
  end

  @doc "A UTC time in `tz`, or left in UTC when there is no zone to move it to."
  def local(nil, _tz), do: nil
  def local(%DateTime{} = dt, nil), do: dt
  def local(%DateTime{} = dt, tz), do: DateTime.shift_zone!(dt, tz)

  defp entry_tz(entry), do: Map.get(entry, :tz)

  defp max_date(a, b), do: if(Date.compare(a, b) == :lt, do: b, else: a)
end
