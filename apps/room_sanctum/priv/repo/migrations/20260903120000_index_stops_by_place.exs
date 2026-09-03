defmodule RoomSanctum.Repo.Migrations.IndexStopsByPlace do
  use Ecto.Migration

  # CREATE INDEX CONCURRENTLY cannot run inside a transaction, and Ecto wraps
  # migrations in one by default.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @moduledoc """
  Make "the stops near here" a question the database can answer.

  GTFS stops carry `stop_lat` and `stop_lon` as plain floats, so finding the
  nearest ones meant reading every row of the largest table in the system.
  There was no such query anywhere as a result.

  The column is generated rather than filled in: the GTFS importer builds its
  bulk inserts from `schema.__schema__(:fields)`, so a normal column would be
  named in every INSERT and would have to be maintained by the import. A
  generated one cannot drift from the coordinates it is derived from, needs no
  backfill, and is invisible to the importer because it stays out of the Ecto
  schema.

  SRID 4326 to match foci, which are stored that way -- comparing geometries
  with different SRIDs is an error rather than a wrong answer, which is at
  least loud, but only at query time.
  """

  def up do
    execute("""
    ALTER TABLE gtfs_stops
      ADD COLUMN place geometry(Point, 4326)
      GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326)
      ) STORED
    """)

    # Concurrently: this table is large and is written by an import that runs
    # on a timer, so a plain CREATE INDEX would hold a lock against it.
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS gtfs_stops_place_index
      ON gtfs_stops USING GIST (place)
    """)
  end

  def down do
    execute("DROP INDEX CONCURRENTLY IF EXISTS gtfs_stops_place_index")
    execute("ALTER TABLE gtfs_stops DROP COLUMN IF EXISTS place")
  end
end
