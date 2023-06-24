defmodule RoomSanctum.Repo.Migrations.SourceAddMetaColumn do
  use Ecto.Migration

  def change do
    alter table("cfg_sources") do
      add :meta, :map, default: %{}
    end
  end
end
