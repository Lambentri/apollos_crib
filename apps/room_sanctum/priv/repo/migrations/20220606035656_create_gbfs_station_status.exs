defmodule RoomSanctum.Repo.Migrations.CreateGbfsStationStatus do
  use Ecto.Migration

  def change do
    create table(:gbfs_station_status) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :legacy_id, :string
      add :num_bikes_available, :integer
      add :num_docks_disabled, :integer
      add :station_id, :string
      add :station_status, :string
      add :num_bikes_disables, :integer
      add :last_reported, :utc_datetime
      add :is_installed, :boolean, default: false, null: false
      add :is_renting, :boolean, default: false, null: false
      add :num_ebikes_available, :integer
      add :num_docks_available, :integer
      add :is_returning, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:gbfs_station_status, [:source_id, :station_id])
  end
end
