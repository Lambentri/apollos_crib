defmodule RoomSanctum.Storage.GBFS.V1.GeoFencingZones do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_geofencing_zones" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :properties, :map
    field :geometry, :map
    field :place, Geo.PostGIS.Geometry

    timestamps()
  end

  @doc false
  def changeset(geo_fencing_zones, attrs) do
    geo_fencing_zones
    |> cast(attrs, [:properties, :geometry, :place])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:place])
  end
end
