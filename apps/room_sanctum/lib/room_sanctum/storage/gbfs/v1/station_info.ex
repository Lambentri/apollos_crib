defmodule RoomSanctum.Storage.GBFS.V1.StationInfo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_station_information" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :capacity, :integer
    field :external_id, :string
    field :lat, :float
    field :legacy_id, :string
    field :lon, :float
    field :name, :string
    field :region_id, :string
    field :rental_methods, {:array, :string}
    field :short_name, :string
    field :station_id, :string
    field :place, Geo.PostGIS.Geometry

    timestamps()
  end

  @doc false
  def changeset(station_info, attrs) do
    station_info
    |> cast(attrs, [
      :station_id,
      :name,
      :short_name,
      :capacity,
      :region_id,
      :legacy_id,
      :external_id,
      :lat,
      :lon,
      :rental_methods,
      :source_id,
      :place
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :station_id,
      :name,
      :short_name,
      :capacity,
      :region_id,
      :legacy_id,
      :external_id,
      :lat,
      :lon,
      :rental_methods,
      :place
    ])
  end
end
