defmodule RoomSanctum.Repo.Migrations.CreateVisions do
  use Ecto.Migration

  def change do
    create table(:cfg_visions) do
      add :name, :string
      add :type, :string
      add :queries, :map
      add :user_id, references(:users, on_delete: :nothing)
      add :public, :boolean
      add :query_ids, {:array, :integer}

      timestamps()
    end

    create index(:cfg_visions, [:user_id])
  end
end
