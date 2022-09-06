defmodule RoomSanctum.Repo.Migrations.CreateCfgPythiae do
  use Ecto.Migration

  def change do
    create table(:cfg_pythiae) do
      add :name, :string
      add :visions, {:array, :integer}
      add :ankyra, {:array, :integer}
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :curr_vision, references(:cfg_visions, on_delete: :nothing)
      add :curr_foci, references(:cfg_focis, on_delete: :nothing)
      add :tweaks, :map

      timestamps()
    end

    create index(:cfg_pythiae, [:user_id])
    create index(:cfg_pythiae, [:curr_vision])
    create index(:cfg_pythiae, [:curr_foci])
  end
end
