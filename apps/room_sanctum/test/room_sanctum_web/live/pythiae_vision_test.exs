defmodule RoomSanctumWeb.PythiaeVisionTest do
  @moduledoc """
  Resolving the visions a pythiae points at.

  The page itself cannot be rendered from this app's tests -- it reads
  users_rabbit, a room_hermes table that is not migrated into room_sanctum's
  test database -- so these cover the lookup the template depends on, which is
  where it was going wrong.
  """
  use ExUnit.Case, async: true

  alias RoomSanctumWeb.PythiaeLive.Show

  defp vision(id, name), do: %{id: id, name: name, meta: %{tint: "teal"}}

  describe "vision_by_id/2" do
    test "finds the vision" do
      assert Show.vision_by_id(7, [vision(7, "Commute")]).name == "Commute"
    end

    test "is nil when the list is empty" do
      # get_by_id/2 hands back the id itself here, which is an integer, and
      # `.name` on it takes the page down
      assert Show.vision_by_id(7, []) == nil
      assert Show.get_by_id(7, []) == 7
    end

    test "is nil for an id pointing at a vision that is gone" do
      assert Show.vision_by_id(99, [vision(7, "Commute")]) == nil
    end

    test "is nil when no current vision has been set" do
      assert Show.vision_by_id(nil, [vision(7, "Commute")]) == nil
    end

    test "picks the right one out of several" do
      visions = [vision(1, "A"), vision(2, "B"), vision(3, "C")]

      assert Show.vision_by_id(2, visions).name == "B"
    end
  end
end
