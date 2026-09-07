defmodule RoomSanctumWeb.StationStreamTest do
  use ExUnit.Case, async: true

  alias RoomSanctumWeb.SourceLive.Stations

  describe "paging" do
    test "a cursor of :done ends the read, whatever the source" do
      # The stream stops on an empty page, so this is what stops it. Without
      # it a source type with no paging would answer its whole list for ever.
      assert {[], :done} = Stations.page(%{type: :gtfs, id: 1}, :done, 20_000)
      assert {[], :done} = Stations.page(%{type: :gbfs, id: 1}, :done, 20_000)
      assert {[], :done} = Stations.page(%{type: :weather, id: 1}, :done, 20_000)
    end

    test "a source with no geography is one empty page rather than a loop" do
      assert {[], :done} = Stations.page(%{type: :weather, id: 1}, nil, 20_000)
    end

    test "the cap still exists for callers that draw many sources at once" do
      # The tint map draws every source sharing a colour; it has not been
      # taught to stream and must not fetch a country per source.
      assert Stations.map_cap() > 0
    end
  end
end
