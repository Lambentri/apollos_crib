defmodule RoomHermes.Repo.Migrations.AddClientIdsToUsersRabbit do
  use Ecto.Migration

  def change do
    alter table(:users_rabbit) do
      add :client_ids, {:array, :string}, default: [], null: false
      add :auto_register_clients, :boolean, default: true, null: false
    end
  end
end
