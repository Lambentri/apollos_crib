defmodule RoomSanctum.Repo.Migrations.CreateGbfsGeofencingZones do
  use Ecto.Migration

  def change do
    create table(:gbfs_geofencing_zones) do
      add :properties, :map
      add :geometry, :map
      add :place, :geometry
      add :source_id, references(:cfg_sources, on_delete: :nothing)

      timestamps()
    end

    create index(:gbfs_geofencing_zones, [:source_id])
  end
end
