defmodule RoomSanctum.Repo.Migrations.IndexStopTimesByStop do
  use Ecto.Migration

  def change do
    # "which routes call at this stop" reads stop_times by stop_id, but the
    # only index there leads with trip_id, so the planner was scanning every
    # trip in the feed and probing per row.
    create index(:gtfs_stop_times, [:source_id, :stop_id])
  end
end
