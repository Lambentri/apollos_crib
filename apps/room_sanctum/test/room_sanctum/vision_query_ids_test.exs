defmodule RoomSanctum.VisionQueryIdsTest do
  @moduledoc """
  A vision can only point at its owner's queries -- the form's picker only
  offers those -- and `query_ids` is what every "which visions is this query
  on" lookup reads, so an id that is someone else's, or nobody's, does not get
  in.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Accounts, Configuration}

  defp user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "seer#{System.unique_integer([:positive])}@example.com",
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
        name: "AAPL",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    query
  end

  test "the owner's own queries are accepted" do
    me = user()
    q = query(me)

    assert {:ok, vision} =
             Configuration.create_vision(%{name: "Mine", user_id: me.id, query_ids: [q.id]})

    assert vision.query_ids == [q.id]
  end

  test "another user's query is refused" do
    me = user()
    theirs = query(user())

    assert {:error, changeset} =
             Configuration.create_vision(%{name: "Mine", user_id: me.id, query_ids: [theirs.id]})

    assert %{query_ids: [_]} = errors_on(changeset)
  end

  test "an id with no query behind it is refused" do
    me = user()
    q = query(me)

    assert {:error, changeset} =
             Configuration.create_vision(%{
               name: "Mine",
               user_id: me.id,
               query_ids: [q.id, q.id + 100_000]
             })

    assert %{query_ids: [_]} = errors_on(changeset)
  end

  test "adding to a vision checks only what is being added" do
    me = user()
    q = query(me)

    {:ok, vision} =
      Configuration.create_vision(%{name: "Mine", user_id: me.id, query_ids: [q.id]})

    # delete_query/1 leaves the id behind on any vision it was pinned to, so
    # stored visions can already hold ids with nothing behind them. They have
    # to stay editable.
    {:ok, _} = Configuration.delete_query(q)
    assert {:ok, renamed} = Configuration.update_vision_ni(vision, %{name: "Renamed"})

    other = query(me)

    assert {:ok, _} =
             Configuration.update_vision_ni(renamed, %{query_ids: renamed.query_ids ++ [other.id]})

    theirs = query(user())

    assert {:error, _} =
             Configuration.update_vision_ni(renamed, %{
               query_ids: renamed.query_ids ++ [theirs.id]
             })
  end
end
