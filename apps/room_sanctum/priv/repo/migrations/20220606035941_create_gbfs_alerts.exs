defmodule RoomSanctum.Repo.Migrations.CreateGbfsAlerts do
  use Ecto.Migration

  def change do
    create table(:gbfs_alerts) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :alert_id, :string
      add :type, :string
      add :times, {:array, :integer}
      add :station_ids, {:array, :string}
      add :region_ids, {:array, :string}
      add :url, :string
      add :summary, :string
      add :description, :string
      add :last_updated, :utc_datetime

      timestamps()
    end

    create unique_index(:gbfs_alerts, [:source_id, :alert_id])
  end
end
