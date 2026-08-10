defmodule RoomSanctum.Repo.Migrations.CreateGtfsShapes do
  use Ecto.Migration

  def change do
    create table(:gtfs_shapes) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false

      add :shape_id, :string, null: false
      add :shape_pt_lat, :float
      add :shape_pt_lon, :float
      add :shape_pt_sequence, :integer
      # Optional in the spec, and MBTA ships it empty.
      add :shape_dist_traveled, :float

      timestamps()
    end

    # The only read is "give me one shape's points in order", which this covers
    # as a prefix scan.
    create index(:gtfs_shapes, [:source_id, :shape_id, :shape_pt_sequence])
  end
end
