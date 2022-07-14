defmodule RoomSanctum.Repo.Migrations.CreateAirnowMonitoringSites do
  use Ecto.Migration

  def change do
    create table(:airnow_monitoring_sites) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :station_id, :string
      add :aqsid, :string
      add :full_aqsid, :string
      add :monitor_type, :string
      add :parameters, {:array, :string}
      add :site_code, :string
      add :site_name, :string
      add :status, :string
      add :agency_id, :string
      add :agency_name, :string
      add :epa_region, :string
      add :point, :geometry
      add :elevation, :float
      add :gmt_offset, :integer
      add :country_fips, :string
      add :cbsa_id, :string
      add :cbsa_name, :string
      add :state_aqs_code, :string
      add :state_abbreviation, :string
      add :county_aqs_code, :string
      add :county_name, :string

      timestamps()
    end

    create unique_index(:airnow_monitoring_sites, [:source_id, :station_id])
  end
end
