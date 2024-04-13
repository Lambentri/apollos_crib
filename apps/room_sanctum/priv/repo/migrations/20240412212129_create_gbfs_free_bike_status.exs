defmodule RoomSanctum.Repo.Migrations.CreateGbfsFreeBikeStatus do
  use Ecto.Migration

  def change do
    create table(:gbfs_free_bike_status) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :bike_id, :string
      add :lat, :float
      add :lon, :float
      add :point, :geometry
      add :is_disabled, :boolean, default: false, null: false
      add :is_reserved, :boolean, default: false, null: false
      add :vehicle_type_id, :string
      add :last_reported, :utc_datetime
      add :current_range_meters, :float
      add :current_fuel_percent, :float
      add :pricing_plan_id, :string

      timestamps()
    end

    create index(:gbfs_free_bike_status, [:source_id])
    create unique_index(:gbfs_free_bike_status, [:source_id, :bike_id])
  end
end
