defmodule RoomSanctum.Storage.GTFS.Calendar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_calendars" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :end_date, :date
    field :friday, :integer
    field :monday, :integer
    field :saturday, :integer
    field :sunday, :integer
    field :service_id, :string
    field :service_name, :string
    field :start_date, :date
    field :thursday, :integer
    field :tuesday, :integer
    field :wednesday, :integer

    timestamps()
  end

  @doc false
  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, [
      :service_id,
      :service_name,
      :monday,
      :tuesday,
      :wednesday,
      :thursday,
      :friday,
      :saturday,
      :sunday,
      :start_date,
      :end_date,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :service_id,
      :monday,
      :tuesday,
      :wednesday,
      :thursday,
      :friday,
      :saturday,
      :sunday
    ])
  end
end
