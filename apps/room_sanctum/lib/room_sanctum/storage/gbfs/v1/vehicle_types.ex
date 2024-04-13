defmodule RoomSanctum.Storage.GBFS.V1.VehicleTypes do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_vehicle_types" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :vehicle_type_id, :string
    field :form_factor, :string
    field :propulsion_type, :string
    field :max_range_meters, :float

    timestamps()
  end

  @doc false
  def changeset(vehicle_types, attrs) do
    vehicle_types
    |> cast(attrs, [:vehicle_type_id, :form_factor, :propulsion_type, :max_range_meters])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:vehicle_type_id, :form_factor, :propulsion_type, :max_range_meters])
  end
end
