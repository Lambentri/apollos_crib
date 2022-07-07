defmodule RoomSanctum.Repo.Migrations.CreateGbfsSystemInformations do
  use Ecto.Migration

  def change do
    create table(:gbfs_system_information) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :name, :string
      add :email, :string
      add :timezone, :string
      add :short_name, :string
      add :phone_number, :string
      add :language, :string
      add :start_date, :date
      add :url, :string
      add :operator, :string
      add :purchase_url, :string
      add :license_url, :string
      add :system_id, :string

      timestamps()
    end

    create unique_index(:gbfs_system_information, [:source_id, :system_id])
  end
end
