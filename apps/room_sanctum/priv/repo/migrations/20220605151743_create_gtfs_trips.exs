defmodule RoomSanctum.Repo.Migrations.CreateTrips do
  use Ecto.Migration

  def change do
    create table(:gtfs_trips) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :route_id, :string
      add :service_id, :string
      add :trip_id, :string
      add :trip_headsign, :string
      add :trip_short_name, :string
      add :direction_id, :integer
      add :block_id, :string
      add :shape_id, :string
      add :wheelchair_accessible, :integer
      add :bikes_allowed, :integer

      timestamps()
    end

    create unique_index(:gtfs_trips, [:source_id, :trip_id])
  end
end
