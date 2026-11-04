defmodule RoomSanctum.VisionDistinctQueriesTest do
  @moduledoc """
  A query belongs on a vision once.

  The form takes the queries other rows hold out of every picker, but that is
  the affordance rather than the rule -- the rule lives on the changeset.
  """
  use RoomSanctum.DataCase

  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.Configuration.Vision

  # A row may only name its owner's queries, so the rows name real ones.
  setup do
    me = owner()
    %{me: me, q: Map.new(1..3, &{&1, query_for(me).id})}
  end

  defp row(query_id, order) do
    %{"type" => "pinned", "data" => %{"__type__" => "pinned", "query" => query_id, "order" => order}}
  end

  defp changeset(rows, me) do
    Vision.changeset(%Vision{}, %{"name" => "Commute", "user_id" => me.id, "queries" => rows})
  end

  test "distinct queries are fine", %{me: me, q: q} do
    assert changeset([row(q[1], 1), row(q[2], 2), row(q[3], 3)], me).valid?
  end

  test "the same query twice is not", %{me: me, q: q} do
    cs = changeset([row(q[1], 1), row(q[2], 2), row(q[1], 3)], me)

    refute cs.valid?
    assert {"each query can only be on a vision once", _} = cs.errors[:queries]
  end

  test "a vision with no queries at all is fine", %{me: me} do
    assert changeset([], me).valid?
  end

  test "rows that name no query yet do not collide with each other", %{me: me} do
    # Two half-filled rows are a form mid-edit, not two of the same query.
    rows = [
      %{"type" => "background", "data" => %{"__type__" => "background", "order" => 1}},
      %{"type" => "background", "data" => %{"__type__" => "background", "order" => 2}}
    ]

    assert changeset(rows, me).valid?
  end
end
