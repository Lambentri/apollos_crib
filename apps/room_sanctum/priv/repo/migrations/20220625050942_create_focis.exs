defmodule RoomSanctum.Repo.Migrations.CreateFocis do
  use Ecto.Migration

  def change do
    create table(:cfg_focis) do
      add :name, :string
      add :place, :geometry
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:focis, [:user_id])
  end
end
