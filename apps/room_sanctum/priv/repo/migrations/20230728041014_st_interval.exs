defmodule RoomSanctum.Repo.Migrations.StInterval do
  use Ecto.Migration

  def change do
    execute """
      ALTER TABLE gtfs_stop_times
    ALTER column departure_time type interval using departure_time::interval;
      ALTER TABLE gtfs_stop_times
    ALTER column arrival_time type interval using arrival_time::interval;
    """
  end
end
