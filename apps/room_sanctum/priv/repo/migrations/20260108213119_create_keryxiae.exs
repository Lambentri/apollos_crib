defmodule RoomSanctum.Repo.Migrations.CreateKeryxiae do
  use Ecto.Migration

  def change do
    create table(:keryxiae) do
      add :name, :string
      add :query_ids, {:array, :integer}
      add :ttl, :integer
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end
  end
end
