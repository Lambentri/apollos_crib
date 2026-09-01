defmodule RoomSanctum.ConfigBroadcastTest do
  @moduledoc """
  Config changes reach the workers by being announced, not by being polled for.

  The workers used to re-read their own config row every two to four seconds,
  which is how a handful of sources kept a ten-connection pool saturated. The
  timers remain as a slow backstop; this is the path that actually carries the
  news.
  """
  use RoomSanctum.DataCase

  alias RoomSanctum.{Accounts, Configuration}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "cfg#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "T", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"},
        meta: %{}
      })

    %{user: user, source: source}
  end

  describe "sources" do
    test "an edit is announced to whoever runs on it", %{source: source} do
      Configuration.subscribe(:source, source.id)

      {:ok, _} = Configuration.update_source(source, %{name: "T2"})

      assert_receive {:cfg_changed, :source, id}
      assert id == source.id
    end

    test "a config change counts, since that is what a worker reads", %{source: source} do
      Configuration.subscribe(:source, source.id)

      {:ok, _} = Configuration.update_source_config(source, %{url_rt_tu: "https://e.test/tu"})

      assert_receive {:cfg_changed, :source, _}
    end

    test "a meta-only write is not announced", %{source: source} do
      Configuration.subscribe(:source, source.id)

      # last_run stamps are written by the workers themselves on a timer.
      # Announcing them would have every worker re-read its config because one
      # of them finished a refresh -- the loop this exists to remove.
      {:ok, _} = Configuration.update_source_meta(source, %{last_run: DateTime.utc_now()})

      refute_receive {:cfg_changed, :source, _}, 100
    end

    test "a failed write announces nothing", %{source: source} do
      Configuration.subscribe(:source, source.id)

      {:error, _} = Configuration.update_source(source, %{type: :not_a_real_type})

      refute_receive {:cfg_changed, :source, _}, 100
    end

    test "only the record you asked about reaches you", %{source: source, user: user} do
      {:ok, other} =
        Configuration.create_source(%{
          name: "U", notes: "", type: :gtfs, enabled: true, user_id: user.id,
          config: %{"__type__" => "gtfs", "url" => "https://e.test/u.zip", "tz" => "UTC"}
        })

      Configuration.subscribe(:source, source.id)

      {:ok, _} = Configuration.update_source(other, %{name: "U2"})

      refute_receive {:cfg_changed, :source, _}, 100
    end

    test "a deleted source says so too", %{source: source} do
      Configuration.subscribe(:source, source.id)

      {:ok, _} = Configuration.delete_source(source)

      assert_receive {:cfg_changed, :source, _}
    end
  end

  describe "the other kinds" do
    test "a vision edit is announced, by either update path", %{user: user} do
      {:ok, vision} = Configuration.create_vision(%{name: "Commute", user_id: user.id})
      Configuration.subscribe(:vision, vision.id)

      {:ok, vision} = Configuration.update_vision(vision, %{name: "Evening"})
      assert_receive {:cfg_changed, :vision, _}

      {:ok, _} = Configuration.update_vision_ni(vision, %{name: "Night"})
      assert_receive {:cfg_changed, :vision, _}
    end

    test "a pythiae edit is announced", %{user: user} do
      {:ok, vision} = Configuration.create_vision(%{name: "Commute", user_id: user.id})

      {:ok, pythiae} =
        Configuration.create_pythiae(%{
          name: "hallway-#{System.unique_integer([:positive])}", user_id: user.id,
          ankyra: [], visions: [vision.id], curr_vision: vision.id
        })

      Configuration.subscribe(:pythiae, pythiae.id)

      {:ok, _} = Configuration.update_pythiae(pythiae, %{curr_vision: nil})

      assert_receive {:cfg_changed, :pythiae, _}
    end
  end
end
