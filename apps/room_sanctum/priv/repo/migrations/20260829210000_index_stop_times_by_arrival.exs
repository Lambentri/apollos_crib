defmodule RoomSanctum.Repo.Migrations.IndexStopTimesByArrival do
  use Ecto.Migration

  # CREATE INDEX takes a lock that blocks writes for as long as it runs, and
  # gtfs_stop_times is millions of rows per feed -- 14s to build on a dev copy,
  # longer in production with imports running. Concurrently instead, which
  # needs its own transaction.
  @disable_ddl_transaction true
  # The migration lock is itself a transaction, and CREATE INDEX CONCURRENTLY
  # cannot run inside one -- without this the migration rolls back before it
  # reaches the index.
  @disable_migration_lock true
  @timeout :infinity

  # if_not_exists throughout, because nothing here is rolled back on failure:
  # a concurrent build runs outside the transaction that records the migration,
  # so a run that dies partway leaves the index behind and un-recorded, and the
  # retry has to be able to step over it. If a build is interrupted rather than
  # failed, Postgres leaves an INVALID index that IF NOT EXISTS will step over
  # too and never finish -- check
  # `select indexrelid::regclass from pg_index where not indisvalid` after any
  # interrupted run, and drop what it names before retrying.

  def up do
    # "the next arrivals at this stop" filters on (source_id, stop_id) and a
    # one-hour window of arrival_time, then orders by arrival_time and takes
    # 16. Leading with the two equalities and ending on arrival_time lets one
    # index scan answer the range, the ordering and the limit together: the
    # scan stops after 16 rows instead of reading every arrival the stop has
    # ever had -- 6,817 of them at the busiest stop in the dev feed -- and
    # sorting them to throw all but 16 away.
    create_if_not_exists index(:gtfs_stop_times, [:source_id, :stop_id, :arrival_time],
                           concurrently: true
                         )

    # Redundant now: a prefix of the index above, which serves every lookup it
    # served (get_trips_for_stop included) without a second 134MB copy to keep
    # written on import.
    drop_if_exists index(:gtfs_stop_times, [:source_id, :stop_id], concurrently: true)
  end

  def down do
    create_if_not_exists index(:gtfs_stop_times, [:source_id, :stop_id], concurrently: true)

    drop_if_exists index(:gtfs_stop_times, [:source_id, :stop_id, :arrival_time],
                     concurrently: true
                   )
  end
end
