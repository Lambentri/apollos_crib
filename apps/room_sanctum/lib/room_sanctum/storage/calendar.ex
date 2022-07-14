defmodule RoomSanctum.Storage.ICalendar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icalendar_entries" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :date_start, :utc_datetime
    field :date_end, :utc_datetime
    field :blob, :map

    timestamps()
  end

  @doc false
  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, [:blob, :source_id, :date_start, :date_end])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:blob, :date_start])
  end
end
