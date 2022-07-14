defmodule RoomSanctum.Storage.GTFS.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_trips" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :bikes_allowed, :integer
    field :block_id, :string
    field :direction_id, :integer
    field :route_id, :string
    field :service_id, :string
    field :shape_id, :string
    field :trip_headsign, :string
    field :trip_id, :string
    field :trip_short_name, :string
    field :wheelchair_accessible, :integer

    timestamps()
  end

  @doc false
  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [
      :route_id,
      :service_id,
      :trip_id,
      :trip_headsign,
      :trip_short_name,
      :direction_id,
      :block_id,
      :shape_id,
      :wheelchair_accessible,
      :bikes_allowed,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :route_id,
      :service_id,
      :trip_id,
      :trip_headsign,
      :trip_short_name,
      :direction_id,
      :block_id,
      :shape_id,
      :wheelchair_accessible,
      :bikes_allowed
    ])
  end
end
