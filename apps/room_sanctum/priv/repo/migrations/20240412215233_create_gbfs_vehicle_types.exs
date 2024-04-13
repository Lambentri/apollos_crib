defmodule RoomSanctum.Repo.Migrations.CreateGbfsVehicleTypes do
  use Ecto.Migration

  def change do
    create table(:gbfs_vehicle_types) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :vehicle_type_id, :string
      add :form_factor, :string
      add :propulsion_type, :string
      add :max_range_meters, :float

      timestamps()
    end

    create index(:gbfs_vehicle_types, [:source_id])
    create unique_index(:gbfs_vehicle_types, [:source_id, :vehicle_type_id])
  end
end
