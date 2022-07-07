defmodule RoomSanctum.Repo.Migrations.CreateStops do
  use Ecto.Migration

  def change do
    create table(:gtfs_stops) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :stop_id, :string
      add :stop_code, :string
      add :stop_name, :string
      add :stop_desc, :string
      add :platform_code, :string
      add :platform_name, :string
      add :stop_lat, :float
      add :stop_lon, :float
      add :zone_id, :string
      add :stop_address, :string
      add :stop_url, :string
      add :level_id, :string
      add :location_type, :string
      add :parent_station, :string
      add :wheelchair_boarding, :integer

      timestamps()
    end

    create unique_index(:gtfs_stops, [:source_id, :stop_id])
  end
end
