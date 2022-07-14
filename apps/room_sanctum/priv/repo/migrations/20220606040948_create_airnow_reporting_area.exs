defmodule RoomSanctum.Repo.Migrations.CreateAirnowReportingArea do
  use Ecto.Migration

  def change do
    create table(:airnow_reporting_area) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :issue_date, :date
      add :valid_date, :date
      add :valid_time, :time
      add :time_zone, :string
      add :record_sequence, :integer
      add :data_type, :string
      add :primary, :string
      add :reporting_area, :string
      add :state_code, :string
      add :lat, :float
      add :lon, :float
      add :parameter_name, :string
      add :aqi_value, :integer
      add :aqi_category, :string
      add :action_day, :boolean, default: false, null: false
      add :discussion, :string
      add :forecast_source, :string

      timestamps()
    end

    create unique_index(:airnow_reporting_area, [:source_id, :site_name, :parameter_name])
  end
end
