defmodule RoomSanctum.Repo.Migrations.CreateAgencies do
  use Ecto.Migration

  def change do
    create table(:gtfs_agencies) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :agency_id, :string
      add :agency_url, :string
      add :agency_lang, :string
      add :agency_name, :string
      add :agency_phone, :string
      add :agency_timezone, :string
      add :agency_fare_url, :string
      add :tts_agency_name, :string

      timestamps()
    end
    create unique_index(:gtfs_agencies, [:source_id, :agency_id])
  end
end
