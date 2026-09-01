defmodule RoomGtfs.DifferentialFeedTest do
  @moduledoc """
  Holding a differential feed open.

  GTFS-RT publishes in two modes that mean opposite things by the same message.
  A full dataset is a snapshot and replaces what was held. A differential feed
  is a stream of edits: each message carries only what changed, keyed by entity
  id, and `is_deleted` means drop it. Replacing on every poll -- correct for the
  first -- silently discards everything the newest delta did not restate.
  """
  use ExUnit.Case, async: true

  alias RoomGtfs.Worker.RT
  alias TransitRealtime, as: T

  defp feed(entities, incrementality) do
    %T.FeedMessage{
      header: %T.FeedHeader{gtfs_realtime_version: "2.0", incrementality: incrementality},
      entity: entities
    }
  end

  defp full(entities), do: feed(entities, :FULL_DATASET)
  defp delta(entities), do: feed(entities, :DIFFERENTIAL)

  # The label rides along on the trip id so an updated entity is telling apart
  # from the one it replaced.
  defp vehicle(id, label \\ "a") do
    %T.FeedEntity{
      id: id,
      vehicle: %T.VehiclePosition{trip: %T.TripDescriptor{trip_id: label}}
    }
  end

  defp deletion(id), do: %T.FeedEntity{id: id, is_deleted: true}

  defp ids(feed), do: Enum.map(feed.entity, & &1.id)
  defp label(feed, id), do: Enum.find(feed.entity, &(&1.id == id)).vehicle.trip.trip_id

  describe "a full dataset" do
    test "replaces whatever was held" do
      held = full([vehicle("a"), vehicle("b")])

      assert RT.merge_feed(held, full([vehicle("c")])) |> ids() == ["c"]
    end

    test "replaces a differential history too, because it is the whole truth" do
      held = delta([vehicle("a"), vehicle("b")])

      assert RT.merge_feed(held, full([vehicle("c")])) |> ids() == ["c"]
    end
  end

  describe "a differential message" do
    test "adds to what is held rather than replacing it" do
      held = delta([vehicle("a"), vehicle("b")])

      assert RT.merge_feed(held, delta([vehicle("c")])) |> ids() == ["a", "b", "c"]
    end

    test "updates an entity in place, keeping its position" do
      held = delta([vehicle("a", "old"), vehicle("b", "old")])

      merged = RT.merge_feed(held, delta([vehicle("a", "new")]))

      assert ids(merged) == ["a", "b"]
      assert label(merged, "a") == "new"
      assert label(merged, "b") == "old"
    end

    test "a deletion drops the entity" do
      held = delta([vehicle("a"), vehicle("b"), vehicle("c")])

      assert RT.merge_feed(held, delta([deletion("b")])) |> ids() == ["a", "c"]
    end

    test "deletions are not themselves kept as entities" do
      merged = RT.merge_feed(delta([vehicle("a")]), delta([deletion("z")]))

      assert ids(merged) == ["a"]
    end

    test "nothing changed is not the feed emptying itself" do
      held = delta([vehicle("a"), vehicle("b")])

      assert RT.merge_feed(held, delta([])) |> ids() == ["a", "b"]
    end

    test "the newest header wins, so freshness is the delta's" do
      held = delta([vehicle("a")])
      incoming = %{delta([]) | header: %T.FeedHeader{gtfs_realtime_version: "2.0", timestamp: 99}}

      assert RT.merge_feed(held, incoming).header.timestamp == 99
    end
  end

  describe "within one message" do
    test "the last word wins for a repeated entity" do
      merged = RT.merge_feed(delta([]), delta([vehicle("a", "first"), vehicle("a", "second")]))

      assert label(merged, "a") == "second"
    end

    test "deleted and then sent again means sent" do
      held = delta([vehicle("a", "old")])

      merged = RT.merge_feed(held, delta([deletion("a"), vehicle("a", "back")]))

      assert ids(merged) == ["a"]
      assert label(merged, "a") == "back"
    end

    test "sent and then deleted means deleted" do
      merged = RT.merge_feed(delta([]), delta([vehicle("a"), deletion("a")]))

      assert ids(merged) == []
    end
  end

  describe "nothing held yet" do
    test "the first delta is applied to an empty feed" do
      assert RT.merge_feed(nil, delta([vehicle("a")])) |> ids() == ["a"]
    end

    test "a first delta deleting something it never sent drops it" do
      assert RT.merge_feed(nil, delta([vehicle("a"), deletion("b")])) |> ids() == ["a"]
    end

    test "a first full dataset is simply the feed" do
      assert RT.merge_feed(nil, full([vehicle("a")])) |> ids() == ["a"]
    end
  end

  test "several polls accumulate the way the feed intends" do
    merged =
      nil
      |> RT.merge_feed(delta([vehicle("a"), vehicle("b")]))
      |> RT.merge_feed(delta([vehicle("c")]))
      |> RT.merge_feed(delta([deletion("a"), vehicle("b", "moved")]))
      |> RT.merge_feed(delta([]))

    assert ids(merged) == ["b", "c"]
    assert label(merged, "b") == "moved"
  end
end
