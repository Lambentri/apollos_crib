defmodule RoomSanctum.Repo.Migrations.AddPythiaeConst do
  use Ecto.Migration

  def change do
    alter table("cfg_pythiae") do
      add :consts, :map
    end
  end
end
