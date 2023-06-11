defmodule RoomSanctum.Repo.Migrations.CreateCfgScribus do
  use Ecto.Migration

  def change do
    create table(:cfg_scribus) do
      add :name, :string
      add :resolution, :string
      add :configuration, {:array, :map}
      add :vision, references(:cfg_visions, on_delete: :nothing)

      timestamps()
    end

    create index(:cfg_scribus, [:vision])
  end
end
