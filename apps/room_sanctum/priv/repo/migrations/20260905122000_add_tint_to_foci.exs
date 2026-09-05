defmodule RoomSanctum.Repo.Migrations.AddTintToFoci do
  use Ecto.Migration

  @moduledoc """
  A colour on a foci, as sources already have.

  Tints are how this app says "these belong together" without making a group
  out of it -- a Plani follows a tint to pick up sources added later without
  being edited. The same shortcut is now wanted for homes: a Plani that follows
  a tint of foci gains a new one the moment it is tinted.
  """

  # Renumbered from 20260905120000, which collided with add_plus_to_pythiae.
  # Ecto keys schema_migrations on the version alone, so the first of the two
  # to run recorded the number and the second was skipped -- while still
  # reporting `:up`, because the version it is looked up by was there.
  # Silent, and it looked exactly like a migration that had run.
  def change do
    alter table(:cfg_focis) do
      add :tint, :string
    end
  end
end
