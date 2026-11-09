defmodule RoomSanctum.QueryOwnedIdsTest do
  @moduledoc """
  A query asks one of its owner's sources, at one of its owner's foci. The
  form only offers those; an id of someone else's, sent in their place, is
  refused rather than queried.
  """
  use RoomSanctum.DataCase

  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.Configuration

  defp weather(user, source, foci) do
    Configuration.create_query(%{
      name: "Outside",
      source_id: source.id,
      user_id: user.id,
      query: %{"__type__" => "weather", "foci_id" => foci.id}
    })
  end

  test "the owner's own source and foci are accepted" do
    me = owner()
    assert {:ok, query} = weather(me, source_for(me), foci_for(me))
    assert query.user_id == me.id
  end

  test "another user's source is refused" do
    me = owner()
    assert {:error, changeset} = weather(me, source_for(owner()), foci_for(me))
    assert %{source_id: [_]} = errors_on(changeset)
  end

  test "another user's foci is refused" do
    me = owner()
    assert {:error, changeset} = weather(me, source_for(me), foci_for(owner()))
    assert %{query: [_]} = errors_on(changeset)
  end

  test "an existing query moved onto another user's source or foci is refused" do
    me = owner()
    {:ok, query} = weather(me, source_for(me), foci_for(me))
    them = owner()

    assert {:error, _} = Configuration.update_query(query, %{source_id: source_for(them).id})

    assert {:error, _} =
             Configuration.update_query(query, %{
               query: %{"__type__" => "weather", "foci_id" => foci_for(them).id}
             })

    assert {:ok, _} = Configuration.update_query(query, %{name: "Renamed"})

    assert {:ok, _} =
             Configuration.update_query(query, %{
               query: %{"__type__" => "weather", "foci_id" => foci_for(me).id}
             })
  end
end
