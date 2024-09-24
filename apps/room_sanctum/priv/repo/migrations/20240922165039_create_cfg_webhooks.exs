defmodule RoomSanctum.Repo.Migrations.CreateCfgWebhooks do
  use Ecto.Migration

  def change do
    create table(:cfg_webhooks) do
      add :source_id, references(:cfg_sources, on_delete: :nothing)
      add :designator, :string
      add :path, :uuid
      add :user, :uuid
      add :token, :string

      timestamps()
    end
  end
end
