defmodule RoomSanctum.Repo.Migrations.CreateStorageMail do
  use Ecto.Migration

  def change do
    create table(:storage_mail) do
      add :meta, :map
      add :body_plain, :text
      add :body_html, :text
      add :mail, references(:cfg_mailboxes, on_delete: :nothing)

      timestamps()
    end

    create index(:storage_mail, [:mail])
  end
end
