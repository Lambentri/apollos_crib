defmodule RoomSanctum.Storage.GTFS.CalendarDate do
  @moduledoc """
  One line of calendar_dates.txt: a service, a date, and whether that date is
  added to the service or taken away from it.

  For some feeds this is not the exception it sounds like. MBTA's bus feed
  carries services whose seven weekday flags in calendar.txt are all zero --
  every day they run is named here instead -- so a service-day filter that
  reads only calendar.txt drops trips that are genuinely running.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @added 1
  @removed 2

  def added, do: @added
  def removed, do: @removed

  schema "gtfs_calendar_dates" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :service_id, :string
    field :date, :date
    field :exception_type, :integer

    timestamps()
  end

  @doc false
  def changeset(calendar_date, attrs) do
    calendar_date
    |> cast(normalize_dates(attrs), [:service_id, :date, :exception_type, :source_id])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:service_id, :date, :exception_type])
    |> validate_inclusion(:exception_type, [@added, @removed])
  end

  # GTFS writes dates as YYYYMMDD, which Ecto's :date cast rejects -- it wants
  # the extended form, and a rejected cast here means a row silently imported
  # with no date at all. Both forms are accepted; anything else is passed
  # through to fail casting rather than be guessed at.
  defp normalize_dates(attrs) do
    Enum.into(attrs, %{}, fn
      {k, v} when k in ["date", :date] -> {k, iso_date(v)}
      pair -> pair
    end)
  end

  defp iso_date(<<y::binary-4, m::binary-2, d::binary-2>> = raw) do
    case Integer.parse(raw) do
      {_, ""} -> "#{y}-#{m}-#{d}"
      _otherwise -> raw
    end
  end

  defp iso_date(other), do: other
end
