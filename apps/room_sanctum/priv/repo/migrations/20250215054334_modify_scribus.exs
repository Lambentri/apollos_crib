defmodule RoomSanctum.Repo.Migrations.ModifyScribus do
  use Ecto.Migration

  def change do
    alter table(:cfg_scribus) do
      add :enabled, :bool
      add :ankyra, :integer
      add :color, :string
      add :wait, :integer
      add :buffer, :integer # seconds
      add :theme, :string
      add :show_name, :bool
      add :show_time, :bool
      add :tz, :string
    end
  end
end
