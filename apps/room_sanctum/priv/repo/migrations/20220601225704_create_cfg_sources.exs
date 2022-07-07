defmodule RoomSanctum.Repo.Migrations.CreateCfgSources do
  use Ecto.Migration

  def change do
    create table(:cfg_sources) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :name, :string
      add :notes, :string
      add :type, :string
      add :enabled, :boolean, default: false, null: false
      add :config, :map

      add :public, :boolean, default: true, null: false

      timestamps()
    end
  end
end
