defmodule RoomSanctum.Repo.Migrations.CreateCfgQueries do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"
    create table(:cfg_queries) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :name, :string
      add :notes, :string
      add :query, :map
      add :source_id, references(:cfg_sources, on_delete: :nothing)

      add :public, :boolean, default: true, null: false
      add :geom, :geometry

      timestamps()
    end

    create index(:cfg_queries, [:source_id])
  end
end
