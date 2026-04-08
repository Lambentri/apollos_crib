defmodule RoomSanctum.Repo.Migrations.AddUniqueIndexToKeryxName do
  use Ecto.Migration

  def change do
    create unique_index(:keryxiae, [:name])
  end
end
