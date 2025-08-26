defmodule RoomSanctum.Repo.Migrations.AddMetaToCfgQueries do
  use Ecto.Migration

  def change do
    alter table("cfg_queries") do
      add :meta, :map, default: %{}
    end
  end
end
