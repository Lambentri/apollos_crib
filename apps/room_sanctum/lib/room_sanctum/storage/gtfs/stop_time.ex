defmodule RoomSanctum.Storage.GTFS.StopTime do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_stop_times" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :arrival_time, EctoInterval
    field :checkpoint_id, :string
    field :continuous_drop_off, :string
    field :continuous_pickup, :string
    field :departure_time, EctoInterval
    field :drop_off_type, :integer
    field :pickup_type, :integer
    field :stop_headsign, :string
    field :stop_id, :string
    field :stop_sequence, :integer
    field :timepoint, :integer
    field :trip_id, :string

    timestamps()
  end

  @doc false
  def changeset(stop_time, attrs) do
    stop_time
    |> cast(attrs, [
      :trip_id,
      :arrival_time,
      :departure_time,
      :stop_id,
      :stop_sequence,
      :stop_headsign,
      :pickup_type,
      :drop_off_type,
      :timepoint,
      :checkpoint_id,
      :continuous_pickup,
      :continuous_dropoff,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :trip_id,
      :arrival_time,
      :departure_time,
      :stop_id,
      :stop_sequence,
      :pickup_type,
      :drop_off_type,
      :timepoint
    ])
  end
end
