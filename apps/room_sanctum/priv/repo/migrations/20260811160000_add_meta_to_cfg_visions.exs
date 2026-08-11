defmodule RoomSanctum.Repo.Migrations.AddMetaToCfgVisions do
  use Ecto.Migration

  @moduledoc """
  Visions get the same meta embed sources and queries have, so a vision can
  carry a tint.
  """

  def change do
    alter table(:cfg_visions) do
      add :meta, :map, default: %{}
    end
  end
end
