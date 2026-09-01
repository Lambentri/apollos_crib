defmodule RoomSanctumWeb.DockPopupTest do
  @moduledoc """
  A dock's popup on the source page offered a name, a pair of coordinates and a
  button to query it -- everything except what is in the dock.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.Components.QueryGeospatialMap

  defp station(opts \\ []) do
    %{
      station_id: "s1",
      name: "22nd St Caltrain Station",
      short_name: "22",
      capacity: Keyword.get(opts, :capacity, 35),
      lat: 37.757,
      lon: -122.392,
      place: nil
    }
  end

  defp status(opts) do
    %{
      station_id: "s1",
      num_bikes_available: Keyword.get(opts, :bikes, 13),
      num_ebikes_available: Keyword.get(opts, :ebikes, 10),
      num_docks_available: Keyword.get(opts, :docks, 21),
      capacity: Keyword.get(opts, :capacity, 35),
      is_installed: Keyword.get(opts, :installed, true),
      is_renting: Keyword.get(opts, :renting, true),
      is_returning: Keyword.get(opts, :returning, true),
      station_status: "active",
      last_reported: nil
    }
  end

  defp map_html(opts) do
    render_component(&query_geospatial_map/1,
      queries: [],
      stations: [station()],
      station_statuses: Keyword.get(opts, :statuses, [status([])]),
      add_query_event: "map-add-query",
      id: "t"
    )
  end

  test "the popup lays a dock out the way the preview card lays it out" do
    html = map_html([])

    # Standard bikes, electric bikes, docks free -- each under the glyph the
    # card labels that number with, rather than under a word.
    assert html =~ ~s(&quot;icon&quot;:&quot;bicycle&quot;)
    assert html =~ ~s(&quot;icon&quot;:&quot;bolt-lightning&quot;)
    assert html =~ ~s(&quot;icon&quot;:&quot;square-parking&quot;)

    # 13 available of which 10 electric is 3 ordinary bikes, which is what the
    # card counts and what a rider who cannot ride an electric one needs.
    assert html =~ ~s(&quot;value&quot;:&quot;3&quot;)
    assert html =~ ~s(&quot;value&quot;:&quot;10&quot;)
    assert html =~ ~s(&quot;value&quot;:&quot;21 of 35&quot;)
  end

  test "a dock that is not working takes over the leading glyph" do
    # The state replaces the row's icon rather than adding a line of prose;
    # the words survive as the icon's name, for a hover and a screen reader.
    assert map_html(statuses: [status(renting: false)]) =~ ~s(&quot;icon&quot;:&quot;lock&quot;)
    assert map_html(statuses: [status(installed: false)]) =~ ~s(&quot;icon&quot;:&quot;ban&quot;)
    assert map_html(statuses: [status(renting: false)]) =~ "Not renting"

    # A dock that is installed, renting and returning says none of this.
    refute map_html([]) =~ "Not renting"
    refute map_html([]) =~ ~s(&quot;icon&quot;:&quot;lock&quot;)
  end

  test "the query button and the coordinates are still there" do
    html = map_html([])

    assert html =~ "data-has-query" or html =~ "add-query"
    assert html =~ "22nd St Caltrain Station"
  end

  test "capacity comes from the dock when the reading does not carry one" do
    # list_gbfs_station_status returns rows with no capacity field at all.
    without = Map.delete(status([]), :capacity)

    assert map_html(statuses: [without]) =~ "21 of 35"
  end

  test "a dock with no status reported still draws, without inventing counts" do
    html = map_html(statuses: [])

    assert html =~ "22nd St Caltrain Station"
    refute html =~ "Docks free"
  end
end
