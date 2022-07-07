defmodule RoomSanctum.Repo.Migrations.CreateStopTimes do
  use Ecto.Migration

  def change do
    create table(:gtfs_stop_times) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :trip_id, :string
      add :arrival_time, :time
      add :departure_time, :time
      add :stop_id, :string
      add :stop_sequence, :integer
      add :stop_headsign, :string
      add :pickup_type, :integer
      add :drop_off_type, :integer
      add :timepoint, :integer
      add :checkpoint_id, :string
      add :continuous_pickup, :string
      add :continuous_dropoff, :string

      timestamps()
    end

    create unique_index(:gtfs_stop_times, [:source_id, :trip_id, :stop_id, :stop_sequence])
  end
end
