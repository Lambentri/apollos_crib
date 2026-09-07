defmodule RoomGtfs.GtfsEntriesTest do
  use ExUnit.Case, async: true

  alias RoomGtfs.Worker.Static

  defp picked(names) do
    names
    |> Enum.map(&%{file_name: &1})
    |> Static.gtfs_entries()
    |> Enum.map(& &1.file_name)
    |> Enum.sort()
  end

  test "a feed at the root of the zip is unchanged" do
    assert picked(["stops.txt", "trips.txt", "feed_info.txt"]) == ["stops.txt", "trips.txt"]
  end

  test "a feed inside a folder is found" do
    # Delhi publishes exactly this shape, and matching the whole path against a
    # list of bare names found nothing at all -- an import that loaded no files
    # and reported no error, which looks identical to one that worked.
    assert picked(["delhi_v1-2/stops.txt", "delhi_v1-2/trips.txt"]) ==
             ["delhi_v1-2/stops.txt", "delhi_v1-2/trips.txt"]
  end

  test "AppleDouble junk from a Mac's zip tool is left out" do
    names = ["ncrtc/stops.txt", "__MACOSX/ncrtc/._stops.txt", "__MACOSX/._ncrtc", "ncrtc/trips.txt"]

    assert picked(names) == ["ncrtc/stops.txt", "ncrtc/trips.txt"]
  end

  test "two feeds in one zip do not become one source" do
    # Taking every stops.txt would merge two agencies. The fuller folder wins.
    names = ["agency_a/stops.txt", "agency_a/trips.txt", "agency_a/routes.txt", "agency_b/stops.txt"]

    assert picked(names) ==
             ["agency_a/routes.txt", "agency_a/stops.txt", "agency_a/trips.txt"]
  end

  test "a tie between folders is resolved the same way every time" do
    # Not by whichever the zip's hash-ordered entry list happened to give.
    assert picked(["b/stops.txt", "a/stops.txt"]) == ["a/stops.txt"]
  end

  test "a zip with nothing recognisable selects nothing rather than raising" do
    assert picked(["readme.md", "__MACOSX/._readme.md"]) == []
    assert picked([]) == []
  end
end
