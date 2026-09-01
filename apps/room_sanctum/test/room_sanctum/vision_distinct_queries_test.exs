defmodule RoomSanctum.VisionDistinctQueriesTest do
  @moduledoc """
  A query belongs on a vision once.

  The form takes the queries other rows hold out of every picker, but that is
  the affordance rather than the rule -- the rule lives on the changeset.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Vision

  defp row(query_id, order) do
    %{"type" => "pinned", "data" => %{"__type__" => "pinned", "query" => query_id, "order" => order}}
  end

  defp changeset(rows) do
    Vision.changeset(%Vision{}, %{"name" => "Commute", "user_id" => 1, "queries" => rows})
  end

  test "distinct queries are fine" do
    assert changeset([row(1, 1), row(2, 2), row(3, 3)]).valid?
  end

  test "the same query twice is not" do
    cs = changeset([row(1, 1), row(2, 2), row(1, 3)])

    refute cs.valid?
    assert {"each query can only be on a vision once", _} = cs.errors[:queries]
  end

  test "a vision with no queries at all is fine" do
    assert changeset([]).valid?
  end

  test "rows that name no query yet do not collide with each other" do
    # Two half-filled rows are a form mid-edit, not two of the same query.
    rows = [
      %{"type" => "background", "data" => %{"__type__" => "background", "order" => 1}},
      %{"type" => "background", "data" => %{"__type__" => "background", "order" => 2}}
    ]

    assert changeset(rows).valid?
  end
end
