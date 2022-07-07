defmodule RoomSanctum.Repo.Migrations.CreateDirections do
  use Ecto.Migration

  def change do
    create table(:gtfs_directions) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :route_id, :string
      add :direction_id, :integer
      add :direction, :string

      timestamps()
    end

    create unique_index(:gtfs_directions, [:source_id, :route_id, :direction_id])
  end
end
