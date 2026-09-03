defmodule RoomSanctumWeb.AnkyraPositionsTest do
  @moduledoc """
  How a reported position is shown as it ages.

  The page itself is not mounted: `users_rabbit` comes from the hermes repo's
  migrations and is not in this test database. What is worth pinning down is
  the fade, which is arithmetic.
  """
  use ExUnit.Case, async: true

  alias RoomSanctumWeb.AnkyraLive.Show

  defp seconds_ago(n), do: %{at: DateTime.add(DateTime.utc_now(), -n, :second)}

  describe "freshness" do
    test "a fix that just arrived is fully opaque" do
      assert_in_delta Show.freshness(seconds_ago(0)), 1.0, 0.01
    end

    test "fades towards, but never to, invisible" do
      half = Show.freshness(seconds_ago(150))
      old = Show.freshness(seconds_ago(299))

      assert half < 1.0
      assert old < half
      # The last one before it is dropped is still readable; a row that fades
      # to nothing looks like a rendering fault rather than an old fix.
      assert old >= 0.25
    end

    test "a fix past its life does not go negative" do
      assert Show.freshness(seconds_ago(10_000)) == 0.25
    end
  end

  describe "age in words" do
    test "reads as an age, not a timestamp" do
      assert Show.age_in_words(seconds_ago(0)) == "just now"
      assert Show.age_in_words(seconds_ago(30)) == "30s ago"
      assert Show.age_in_words(seconds_ago(125)) == "2m ago"
    end
  end
end
