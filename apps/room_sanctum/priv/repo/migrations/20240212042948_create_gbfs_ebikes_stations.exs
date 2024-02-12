defmodule RoomSanctum.Repo.Migrations.CreateGbfsEbikesStations do
  use Ecto.Migration

  def change do
    create table(:gbfs_ebikes_stations) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :station_id, :string
      add :ebikes, :map

      timestamps()
    end

    create unique_index(:gbfs_ebikes_stations, [:source_id, :station_id])
  end
end
