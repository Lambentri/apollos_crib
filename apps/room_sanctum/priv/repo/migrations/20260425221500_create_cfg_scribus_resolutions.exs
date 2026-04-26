defmodule RoomSanctum.Repo.Migrations.CreateCfgScribusResolutions do
  use Ecto.Migration

  @defaults [
    {"180x180", 180, 180},
    {"450x600", 450, 600},
    {"540x960", 540, 960},
    {"800x1280", 800, 1280},
    {"1404x1872", 1404, 1872}
  ]

  def change do
    create table(:cfg_scribus_resolutions) do
      add :name, :string, null: false
      add :width, :integer, null: false
      add :height, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:cfg_scribus_resolutions, [:user_id])
    create unique_index(:cfg_scribus_resolutions, [:user_id, :name])

    flush()

    for [user_id] <- repo().query!("SELECT id FROM users").rows,
        {name, w, h} <- @defaults do
      repo().query!(
        "INSERT INTO cfg_scribus_resolutions (name, width, height, user_id, inserted_at, updated_at) VALUES ($1, $2, $3, $4, NOW(), NOW())",
        [name, w, h, user_id]
      )
    end
  end
end
