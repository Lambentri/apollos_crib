defmodule RoomSanctum.Repo.Migrations.CreateCfgMailboxes do
  use Ecto.Migration

  def change do
    create table(:cfg_mailboxes) do
      add :designator, :string
      add :user, :string
      add :source_id, references(:cfg_sources, on_delete: :nothing)

      timestamps()
    end

    create index(:cfg_mailboxes, [:source])
  end
end
