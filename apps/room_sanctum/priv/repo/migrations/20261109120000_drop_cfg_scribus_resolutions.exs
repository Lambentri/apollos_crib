defmodule RoomSanctum.Repo.Migrations.DropCfgScribusResolutions do
  use Ecto.Migration

  # Resolutions are now the browser-ctl MutantDeployment's mutations, read
  # from the mutant operator (RoomSanctum.Mutants). Rolling back recreates
  # the table empty.
  def up do
    drop table(:cfg_scribus_resolutions)
  end

  def down do
    create table(:cfg_scribus_resolutions) do
      add :name, :string, null: false
      add :width, :integer, null: false
      add :height, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:cfg_scribus_resolutions, [:user_id])
    create unique_index(:cfg_scribus_resolutions, [:user_id, :name])
  end
end
