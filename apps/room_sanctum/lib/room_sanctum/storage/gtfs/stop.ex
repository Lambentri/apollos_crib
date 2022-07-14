defmodule RoomSanctum.Storage.GTFS.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_stops" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :level_id, :string
    field :location_type, :string
    field :parent_station, :string
    field :platform_code, :string
    field :platform_name, :string
    field :stop_address, :string
    field :stop_code, :string
    field :stop_desc, :string
    field :stop_id, :string
    field :stop_lat, :float
    field :stop_lon, :float
    field :stop_name, :string
    field :stop_url, :string
    field :wheelchair_boarding, :integer
    field :zone_id, :string

    timestamps()
  end

  @doc false
  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [
      :stop_id,
      :stop_code,
      :stop_name,
      :stop_desc,
      :platform_code,
      :platform_name,
      :stop_lat,
      :stop_lon,
      :zone_id,
      :stop_address,
      :stop_url,
      :level_id,
      :location_type,
      :parent_station,
      :wheelchair_boarding,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :stop_id,
      :stop_code,
      :stop_name,
      :stop_lat,
      :stop_lon,
      :zone_id,
      :stop_url,
      :location_type,
      :wheelchair_boarding
    ])
  end
end
