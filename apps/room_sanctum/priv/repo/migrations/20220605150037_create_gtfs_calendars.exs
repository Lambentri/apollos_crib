defmodule RoomSanctum.Repo.Migrations.CreateCalendars do
  use Ecto.Migration

  def change do
    create table(:gtfs_calendars) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :service_id, :string
      add :service_name, :string
      add :monday, :integer
      add :tuesday, :integer
      add :wednesday, :integer
      add :thursday, :integer
      add :friday, :integer
      add :saturday, :integer
      add :sunday, :integer
      add :start_date, :date
      add :end_date, :date

      timestamps()
    end

    create unique_index(:gtfs_calendars, [:source_id, :service_id])
  end
end
