defmodule RoomSanctum.Repo.Migrations.CreateGtfsCalendarDates do
  use Ecto.Migration

  # calendar_dates.txt was the one part of a feed's service definition this app
  # did not read, and for several feeds it is where most of the definition
  # lives. MBTA's bus feed has services whose seven day flags are all zero and
  # whose date range is a single day -- they run entirely on exceptions here,
  # and without this table there is no way to know which trips run today.
  def change do
    create table(:gtfs_calendar_dates) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :service_id, :string, null: false
      add :date, :date, null: false
      # 1 adds service for that date, 2 removes it.
      add :exception_type, :integer, null: false

      timestamps()
    end

    # A service names a given date once. The import upserts on this.
    create unique_index(:gtfs_calendar_dates, [:source_id, :service_id, :date])

    # "which services run on this date", which is how the arrival query will
    # read it: by day, not by service.
    create index(:gtfs_calendar_dates, [:source_id, :date])
  end
end
