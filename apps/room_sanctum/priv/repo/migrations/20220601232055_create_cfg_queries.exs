defmodule RoomSanctum.Repo.Migrations.CreateCfgQueries do
  use Ecto.Migration

  def change do
    create table(:cfg_queries) do
      add :name, :string
      add :notes, :string
      add :query, :map
      add :source_id, references(:cfg_sources, on_delete: :nothing)

      timestamps()
    end

    create index(:cfg_queries, [:source_id])
  end
end
