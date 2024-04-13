defmodule RoomSanctum.Storage.GBFS.V1.FreeBikeStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_free_bike_status" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :bike_id, :string
    field :lat, :float
    field :lon, :float
    field :point, Geo.PostGIS.Geometry
    field :is_disabled, :boolean, default: false
    field :is_reserved, :boolean, default: false
    field :vehicle_type_id, :string
    field :last_reported, :utc_datetime
    field :current_range_meters, :float
    field :current_fuel_percent, :float
    field :pricing_plan_id, :string

    timestamps()
  end

  @doc false
  def changeset(free_bike_status, attrs) do
    free_bike_status
    |> cast(attrs, [:bike_id, :lat, :lon, :point, :is_disabled, :is_reserved, :vehicle_type_id, :last_reported, :current_range_meters, :current_fuel_percent, :pricing_plan_id])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:bike_id, :lat, :lon, :point, :is_disabled, :is_reserved, :vehicle_type_id, :last_reported, :current_range_meters, :current_fuel_percent, :pricing_plan_id])
  end
end
