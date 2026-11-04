defmodule RoomSanctum.ScribusOwnerMigrationTest do
  @moduledoc """
  The migration that gives every scribus an owner: the rows already there go
  to the first user, and the column ends up required and referencing users
  the way the other cfg tables' does.
  """
  use RoomSanctum.DataCase

  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.Repo

  Code.require_file(
    "../../priv/repo/migrations/20261104224340_add_user_id_to_cfg_scribus.exs",
    __DIR__
  )

  alias RoomSanctum.Repo.Migrations.AddUserIdToCfgScribus

  defp plant(name, user_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {1, [%{id: id}]} =
      Repo.insert_all(
        "cfg_scribus",
        [
          %{
            name: name,
            resolution: "800x480",
            user_id: user_id,
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    id
  end

  defp owner_of(id) do
    %{rows: [[user_id]]} = Repo.query!("SELECT user_id FROM cfg_scribus WHERE id = $1", [id])
    user_id
  end

  test "rows with no owner go to the first user, and owned rows are left alone" do
    # The rows as they were before the migration: the column there, nothing
    # in it. Undone with the rest of the test's transaction.
    Repo.query!("ALTER TABLE cfg_scribus ALTER COLUMN user_id DROP NOT NULL")

    first = owner()
    second = owner()
    %{rows: [[lowest]]} = Repo.query!("SELECT min(id) FROM users")
    assert lowest <= first.id

    kitchen = plant("Kitchen", nil)
    hall = plant("Hall", nil)
    theirs = plant("Theirs", second.id)

    Repo.query!(AddUserIdToCfgScribus.backfill_sql())

    assert owner_of(kitchen) == lowest
    assert owner_of(hall) == lowest
    assert owner_of(theirs) == second.id
  end

  test "the column is required and references users as the other cfg tables' does" do
    %{rows: [[nullable]]} =
      Repo.query!("""
      SELECT is_nullable FROM information_schema.columns
      WHERE table_name = 'cfg_scribus' AND column_name = 'user_id'
      """)

    assert nullable == "NO"

    # 'n' is ON DELETE SET NULL, Ecto's :nilify_all.
    %{rows: rows} =
      Repo.query!("""
      SELECT c.conrelid::regclass::text, c.confdeltype
      FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
      WHERE c.contype = 'f' AND c.confrelid = 'users'::regclass AND a.attname = 'user_id'
        AND c.conrelid::regclass::text IN ('cfg_scribus', 'cfg_pythiae', 'cfg_queries')
      """)

    assert {"cfg_scribus", "n"} in Enum.map(rows, &List.to_tuple/1)
    assert rows |> Enum.map(&List.last/1) |> Enum.uniq() == ["n"]
  end
end
