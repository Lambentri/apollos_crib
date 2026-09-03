defmodule RoomSanctum.Repo.Migrations.AddFollowTintToPlani do
  use Ecto.Migration

  @moduledoc """
  Following a tint rather than naming every source.

  Sources are already tinted, and a tint is usually the thing a group of them
  has in common -- everything about getting to work, everything about the
  coast. Following one means a source tinted later joins without the Plani
  being edited, which is the difference between a shortcut and a bulk select.
  """

  def change do
    alter table(:cfg_plani) do
      add :follow_tint, :string
    end
  end
end
