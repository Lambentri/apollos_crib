defmodule RoomSanctum.DeleteQueryVisionsTest do
  @moduledoc """
  Deleting a query takes it off every vision it was on -- the `query_ids` and
  the embedded list both -- in the same transaction as the delete. And the
  migration that clears the ids the old deletes left behind.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Accounts, Configuration, Repo}

  Code.require_file(
    "../../priv/repo/migrations/20261104221416_strip_dangling_vision_query_ids.exs",
    __DIR__
  )

  alias RoomSanctum.Repo.Migrations.StripDanglingVisionQueryIds

  defp user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "dq#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    user
  end

  defp query(user) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "Markets",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    {:ok, query} =
      Configuration.create_query(%{
        name: "q",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    query
  end

  defp embed(query_id, order) do
    %{
      "id" => nil,
      "type" => "pinned",
      "data" => %{"order" => order, "query" => query_id, "__type__" => "pinned"}
    }
  end

  # Written straight to the row, the way the pages and older code left them:
  # no changeset in the way, so ids with nothing behind them, a query saved as
  # a string, and an embed duplicated by the old re-pinning all go in as-is.
  defp vision(user, query_ids, embeds) do
    {:ok, vision} = Configuration.create_vision(%{name: "Dash", user_id: user.id})

    Repo.query!("UPDATE cfg_visions SET query_ids = $2, queries = $3 WHERE id = $1", [
      vision.id,
      query_ids,
      embeds
    ])

    vision
  end

  defp raw(vision) do
    %{rows: [[ids, queries]]} =
      Repo.query!("SELECT query_ids, queries FROM cfg_visions WHERE id = $1", [vision.id])

    {ids, Enum.map(queries, &get_in(&1, ["data", "query"]))}
  end

  describe "delete_query/1" do
    test "takes the query off the visions it was on, both halves" do
      me = user()
      gone = query(me)
      kept = query(me)
      v = vision(me, [gone.id, kept.id], [embed(gone.id, 0), embed(kept.id, 1)])

      assert {:ok, _} = Configuration.delete_query(gone)

      assert raw(v) == {[kept.id], [kept.id]}
    end

    test "catches duplicated embeds and one saved as a string" do
      me = user()
      gone = query(me)
      kept = query(me)

      v =
        vision(me, [gone.id, kept.id], [
          embed(gone.id, 0),
          embed(kept.id, 1),
          embed(to_string(gone.id), 2),
          embed(gone.id, 3)
        ])

      assert {:ok, _} = Configuration.delete_query(gone)

      assert raw(v) == {[kept.id], [kept.id]}
    end

    test "leaves visions that do not hold it alone, whoever owns them" do
      me = user()
      them = user()
      gone = query(me)
      mine = query(me)
      theirs = query(them)

      my_other = vision(me, [mine.id], [embed(mine.id, 0)])
      their_vision = vision(them, [theirs.id], [embed(theirs.id, 0)])
      before = Repo.reload!(their_vision)

      assert {:ok, _} = Configuration.delete_query(gone)

      assert raw(my_other) == {[mine.id], [mine.id]}
      assert raw(their_vision) == {[theirs.id], [theirs.id]}
      assert Repo.reload!(their_vision).updated_at == before.updated_at
    end

    test "a vision with no query_ids at all keeps them nil" do
      me = user()
      gone = query(me)
      v = vision(me, nil, [embed(gone.id, 0)])

      assert {:ok, _} = Configuration.delete_query(gone)

      assert raw(v) == {nil, []}
    end

    test "tells the visions' workers once it has committed" do
      me = user()
      gone = query(me)
      v = vision(me, [gone.id], [embed(gone.id, 0)])
      Configuration.subscribe(:vision, v.id)

      assert {:ok, _} = Configuration.delete_query(gone)

      assert_receive {:cfg_changed, :vision, id} when id == v.id
    end

    test "a delete that fails leaves the visions as they were" do
      me = user()
      gone = query(me)
      # The row goes first, so the delete itself raises on a stale entry --
      # after the visions were already rewritten inside the transaction.
      Repo.delete!(gone)
      v = vision(me, [gone.id], [embed(gone.id, 0)])

      assert_raise Ecto.StaleEntryError, fn -> Configuration.delete_query(gone) end

      assert raw(v) == {[gone.id], [gone.id]}
    end
  end

  describe "the cleanup migration" do
    test "strips ids with no query behind them, and only those" do
      me = user()
      them = user()
      real = query(me)
      dangling = real.id + 100_000

      v =
        vision(me, [real.id, dangling], [
          embed(dangling, 0),
          embed(real.id, 1),
          embed(to_string(dangling), 2),
          # A background row never given a query is not dangling.
          %{
            "id" => nil,
            "type" => "background",
            "data" => %{"order" => 3, "__type__" => "background"}
          }
        ])

      theirs = query(them)
      their_vision = vision(them, [theirs.id], [embed(theirs.id, 0)])
      untouched = Repo.reload!(their_vision)

      Repo.query!(StripDanglingVisionQueryIds.cleanup_sql())

      assert raw(v) == {[real.id], [real.id, nil]}
      assert raw(their_vision) == {[theirs.id], [theirs.id]}
      assert Repo.reload!(their_vision).updated_at == untouched.updated_at
    end

    test "keeps nil query_ids nil" do
      me = user()
      v = vision(me, nil, [embed(123_456_789, 0)])

      Repo.query!(StripDanglingVisionQueryIds.cleanup_sql())

      assert raw(v) == {nil, []}
    end
  end
end
