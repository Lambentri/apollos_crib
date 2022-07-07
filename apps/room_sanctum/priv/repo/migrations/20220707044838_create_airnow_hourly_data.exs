defmodule RoomSanctum.Repo.Migrations.CreateAirnowHourlyData do
  use Ecto.Migration

  def change do
    create table(:airnow_hourly_data) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :valid_date, :date
      add :valid_time, :time
      add :aqsid, :string
      add :site_name, :string
      add :gmt_offset, :integer
      add :parameter_name, :string
      add :reporting_units, :string
      add :value, :integer
      add :data_source, :string

      timestamps()
    end

    create unique_index(:airnow_hourly_data, [:source_id, :site_name, :parameter_name])
  end
end
