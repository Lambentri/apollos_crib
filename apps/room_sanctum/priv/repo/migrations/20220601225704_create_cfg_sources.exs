defmodule RoomSanctum.Repo.Migrations.CreateCfgSources do
  use Ecto.Migration

  def change do
    create table(:cfg_sources) do
      add :name, :string
      add :notes, :string
      add :type, :string
      add :enabled, :boolean, default: false, null: false
      add :config, :map

      timestamps()
    end
  end
end
