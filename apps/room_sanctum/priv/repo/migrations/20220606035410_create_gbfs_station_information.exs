defmodule RoomSanctum.Repo.Migrations.CreateGbfsStationInformation do
  use Ecto.Migration

  def change do
    create table(:gbfs_station_information) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :station_id, :string
      add :name, :string
      add :short_name, :string
      add :capacity, :integer
      add :region_id, :string
      add :legacy_id, :string
      add :external_id, :string
      add :lat, :float
      add :lon, :float
      add :rental_methods, {:array, :string}

      timestamps()
    end

    create unique_index(:gbfs_station_information, [:source_id, :station_id])
  end
end