defmodule RoomSanctum.Repo.Migrations.CreateVisions do
  use Ecto.Migration

  def change do
    create table(:cfg_visions) do
      add :name, :string
      add :type, :string
      add :queries, :map
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:visions, [:user_id])
  end
end
