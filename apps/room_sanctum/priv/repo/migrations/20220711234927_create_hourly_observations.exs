defmodule RoomSanctum.Repo.Migrations.CreateHourlyObservations do
  use Ecto.Migration

  def change do
    create table(:airnow_hourly_observations) do
      add :aqsid, :string
      add :site_name, :string
      add :status, :string
      add :epa_region, :string
      add :lat, :float
      add :lon, :float
      add :point, :geometry
      add :elevation, :float
      add :gmt_offset, :float
      add :country_code, :string
      add :state_name, :string
      add :valid_date, :date
      add :valid_time, :time
      add :data_source, :string
      add :reporting_areas, {:array, :string}
      add :ozone_aqi, :integer
      add :pm10_aqi, :integer
      add :pm25_aqi, :integer
      add :no2_aqi, :integer
      add :ozone_measured, :boolean, default: false, null: false
      add :pm10_measured, :boolean, default: false, null: false
      add :pm25_measured, :boolean, default: false, null: false
      add :no2_measured, :boolean, default: false, null: false
      add :no2, :float
      add :no2_unit, :string
      add :pm25, :float
      add :pm25_unit, :string
      add :ozone, :float
      add :ozone_unit, :string
      add :co, :float
      add :co_unit, :string
      add :so2, :float
      add :so2_unit, :string
      add :pm10, :float
      add :pm10_unit, :string
      add :source_id, references(:cfg_sources, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:airnow_hourly_observations, [:source_id])
    create unique_index(:airnow_hourly_observations, [:source_id, :aqsid])
  end
end
