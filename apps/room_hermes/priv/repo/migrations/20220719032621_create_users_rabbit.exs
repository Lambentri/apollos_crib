defmodule RoomHermes.Repo.Migrations.CreateUsersRabbit do
  use Ecto.Migration

  def change do
    create table(:users_rabbit) do
      add :username, :binary_id
      add :password, :string
      add :topic, :string
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:users_rabbit, [:user_id])
  end
end
