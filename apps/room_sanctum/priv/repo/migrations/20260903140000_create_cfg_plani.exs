defmodule RoomSanctum.Repo.Migrations.CreateCfgPlani do
  use Ecto.Migration

  @moduledoc """
  A Plani: a vision whose anchor moves.

  A sibling of a vision rather than a mode on one. A vision is a fixed list of
  queries and answers the same thing wherever it is read; a Plani is a list of
  sources and answers "what is near me", where "me" is whichever client is
  reporting to it.

  No column here holds a position. The anchor lives in the Plani's worker and
  expires there; `home_foci_id` is what answers when nothing has reported, so
  a Plani that has never heard from anybody still has something to say.
  """

  def change do
    create table(:cfg_plani) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :nothing)

      # Where it falls back to. Not nullable: a Plani with no home and no
      # client reporting would have nowhere to be.
      add :home_foci_id, references(:cfg_focis, on_delete: :nilify_all), null: false

      # Whose position to follow. An Ankyra can have several clients on it --
      # a phone and a panel -- and only one of them is the one that moves.
      #
      # A plain integer, not a reference: users_rabbit is created by the hermes
      # repo's migrations, and a foreign key to it would make this repo's
      # migrations unrunnable on their own. cfg_pythiae holds its ankyra the
      # same way and for the same reason.
      add :ankyra_id, :integer
      add :client_id, :string

      # What to look for around it, and how much of it.
      add :sources, {:array, :integer}, default: [], null: false
      add :radius, :integer, default: 800, null: false
      add :limit, :integer, default: 5, null: false

      timestamps()
    end

    create index(:cfg_plani, [:user_id])
    create index(:cfg_plani, [:ankyra_id])
  end
end
