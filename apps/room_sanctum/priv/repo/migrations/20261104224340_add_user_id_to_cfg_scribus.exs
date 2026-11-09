defmodule RoomSanctum.Repo.Migrations.AddUserIdToCfgScribus do
  use Ecto.Migration

  @moduledoc """
  A scribus had no owner, so every signed-in user could list, open, edit and
  delete every scribus. It gets one, as the other cfg tables have: a reference
  to users, required.

  Nobody can say who made the scribus rows already there, so they all go to
  the first user -- the lowest users.id, which on an installation with one
  person on it is that person. Plain SQL, so it does not depend on the schema
  modules as they happen to be when it runs. Rows with no user to give them
  to (scribus rows, but no users at all) make the NOT NULL fail, which is the
  right outcome: there is nobody to hand them to.
  """

  @doc false
  # Exposed so the test can run it against rows it planted.
  def backfill_sql do
    """
    UPDATE cfg_scribus
    SET user_id = (SELECT id FROM users ORDER BY id LIMIT 1)
    WHERE user_id IS NULL
    """
  end

  def up do
    alter table(:cfg_scribus) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:cfg_scribus, [:user_id])

    execute(backfill_sql())

    alter table(:cfg_scribus) do
      modify :user_id, :bigint, null: false
    end
  end

  def down do
    alter table(:cfg_scribus) do
      remove :user_id
    end
  end
end
