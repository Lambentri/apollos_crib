defmodule RoomSanctum.Repo.Migrations.CreateIcalendarEntries do
  use Ecto.Migration

  def change do
    create table(:icalendar_entries) do
      add :blob, :map
      add :source_id, references(:cfg_sources, on_delete: :nothing)
      add :date_start, :utc_datetime
      add :date_end, :utc_datetime

      timestamps()
    end

    create index(:icalendar_entries, [:source_id])
    create unique_index(:icalendar_entries, [:source_id, :blob])
  end
end
