defmodule RoomSanctum.Repo.Migrations.CreateNeiamAuthIdentities do
  use Ecto.Migration

  # neiam_auth: one row per (user, identity provider). Keyed by
  # (issuer, sub); the provider id is for display only.
  def change do
    create table(:neiam_auth_identities, primary_key: false) do
      add :id, :bigserial, primary_key: true

      add :user_id, references(:users, type: :bigint, on_delete: :delete_all), null: false

      add :provider, :text, null: false
      add :issuer, :text, null: false
      add :sub, :text, null: false
      add :preferred_username, :text
      add :email, :text
      add :groups, {:array, :text}, null: false, default: []
      add :last_auth_time, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:neiam_auth_identities, [:issuer, :sub])
    create unique_index(:neiam_auth_identities, [:issuer, :user_id])
    create index(:neiam_auth_identities, [:user_id])
  end
end
