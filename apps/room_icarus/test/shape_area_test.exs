defmodule RoomIcarus.ShapeAreaTest do
  @moduledoc """
  Shaping an area query's results: altitude and class filters, nearest-first,
  then the count cap.

  The cap has to come last. Trimming before the filters would let a limit of 5
  return two aircraft, because three of the nearest five were the wrong class.
  """
  use ExUnit.Case, async: true

  alias RoomIcarus.Worker

  # "dst" is the feed's distance in nautical miles, which is what the sort and
  # so the cap key off.
  defp plane(hex, dst, attrs \\ %{}) do
    Map.merge(%{"hex" => hex, "dst" => dst, "alt_baro" => 10_000}, attrs)
  end

  defp hexes(list), do: Enum.map(list, & &1["hex"])

  defp scattered do
    [
      plane("far", 40),
      plane("near", 2),
      plane("mid", 20)
    ]
  end

  describe "the count cap" do
    test "keeps the nearest, whatever order the feed sent them in" do
      assert hexes(Worker.shape_area(scattered(), %{limit: 2})) == ["near", "mid"]
    end

    test "a limit of one leaves the closest" do
      assert hexes(Worker.shape_area(scattered(), %{limit: 1})) == ["near"]
    end

    test "no limit shows everything, still nearest-first" do
      assert hexes(Worker.shape_area(scattered(), %{})) == ["near", "mid", "far"]
      assert hexes(Worker.shape_area(scattered(), %{limit: nil})) == ["near", "mid", "far"]
    end

    test "a limit larger than the sky is not an error" do
      assert length(Worker.shape_area(scattered(), %{limit: 500})) == 3
    end

    test "asking for none is treated as no limit, not an empty sky" do
      # the form validates limit >= 1, so a zero can only arrive from a hand
      # edited query -- showing everything beats silently showing nothing
      assert length(Worker.shape_area(scattered(), %{limit: 0})) == 3
      assert length(Worker.shape_area(scattered(), %{limit: -3})) == 3
    end

    test "a limit arriving as a string still counts" do
      # queries come back through the embed as integers, but the worker reads
      # string-keyed maps from the cache too
      assert hexes(Worker.shape_area(scattered(), %{"limit" => "2"})) == ["near", "mid"]
    end

    test "junk in the limit is ignored rather than blanking the map" do
      assert length(Worker.shape_area(scattered(), %{limit: "lots"})) == 3
    end
  end

  describe "the cap runs after the filters, not before" do
    test "a limit fills up with aircraft that match the class" do
      list = [
        plane("mil1", 1, %{"military" => true}),
        plane("mil2", 2, %{"military" => true}),
        plane("ual", 3, %{"flight" => "UAL558"}),
        plane("dal", 4, %{"flight" => "DAL221"})
      ]

      # the two nearest are military, so a naive cap-then-filter would return
      # nothing at all here
      assert hexes(Worker.shape_area(list, %{classes: ["commercial"], limit: 2})) ==
               ["ual", "dal"]
    end

    test "a limit fills up with aircraft inside the altitude band" do
      list = [
        plane("low1", 1, %{"alt_baro" => 500}),
        plane("low2", 2, %{"alt_baro" => 800}),
        plane("high1", 3, %{"alt_baro" => 30_000}),
        plane("high2", 4, %{"alt_baro" => 31_000})
      ]

      assert hexes(Worker.shape_area(list, %{alt_min: 10_000, limit: 2})) == ["high1", "high2"]
    end

    test "an empty sky stays empty" do
      assert Worker.shape_area([], %{limit: 5}) == []
    end
  end

  describe "what the cap does not change" do
    test "filters still apply when there is no limit" do
      list = [plane("ground", 1, %{"alt_baro" => "ground"}), plane("up", 2)]

      assert hexes(Worker.shape_area(list, %{alt_min: 1_000})) == ["up"]
    end

    test "aircraft with no distance sort first and are kept by a limit" do
      # "dst" missing reads as 0, so these lead -- worth pinning, since it
      # decides what a limit of 1 returns
      list = [plane("known", 5), Map.delete(plane("unknown", 0), "dst")]

      assert hexes(Worker.shape_area(list, %{limit: 1})) == ["unknown"]
    end
  end
end
