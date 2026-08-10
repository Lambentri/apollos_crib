defmodule RoomSanctumWeb.AircraftMapTest do
  @moduledoc """
  ADS-B aircraft on the map. Positions arrive string-keyed, straight off the
  adsb.fi payload, which is what room_icarus normalises them to.
  """
  use RoomSanctumWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.Components.QueryGeospatialMap

  defp plane(attrs) do
    Map.merge(
      %{
        "hex" => "a1b2c3",
        "flight" => "UAL558",
        "lat" => 37.62,
        "lon" => -122.38,
        "track" => 271.4,
        "class" => "commercial",
        "alt_baro" => 32_000,
        "gs" => 450,
        "registration" => "N12345",
        "type" => "B739"
      },
      attrs
    )
  end

  defp render_map(aircraft) do
    render_component(&query_geospatial_map/1, queries: [], aircraft: aircraft)
  end

  test "an aircraft becomes a marker carrying its track and class" do
    html = render_map([plane(%{})])

    assert html =~ ~s(id="geospatial-map-marker-aircraft_a1b2c3")
    assert html =~ ~s(type="aircraft")
    assert html =~ ~s(bearing="271.4")
    assert html =~ ~s(aircraft-class="commercial")
  end

  test "the callsign labels the marker" do
    assert render_map([plane(%{})]) =~ ~s(name="UAL558")
  end

  test "without a callsign it falls back to the registration, then the icao address" do
    assert render_map([plane(%{"flight" => nil})]) =~ ~s(name="N12345")

    assert render_map([plane(%{"flight" => nil, "registration" => nil})]) =~
             ~s(name="a1b2c3")
  end

  test "an aircraft with no position is dropped rather than plotted at null island" do
    html = render_map([plane(%{"hex" => "ghost", "lat" => nil, "lon" => nil})])

    refute html =~ "aircraft_ghost"
    refute html =~ ~s(lat="0")
  end

  test "a partial position is not good enough either" do
    refute render_map([plane(%{"hex" => "half", "lon" => nil})]) =~ "aircraft_half"
  end

  test "an aircraft not transmitting a track still gets a marker" do
    html = render_map([plane(%{"track" => nil})])

    assert html =~ "aircraft_a1b2c3"
    # no bearing to claim: the map draws it as a disc rather than pointing it
    refute html =~ ~s(bearing="271.4")
  end

  test "several aircraft each get their own marker" do
    html =
      render_map([
        plane(%{"hex" => "aaa", "flight" => "AAL1"}),
        plane(%{"hex" => "bbb", "flight" => "SWA2", "class" => "cargo"}),
        plane(%{"hex" => "ccc", "flight" => "RCH3", "class" => "military"})
      ])

    for hex <- ~w(aaa bbb ccc), do: assert(html =~ "aircraft_#{hex}")
    assert html =~ ~s(aircraft-class="cargo")
    assert html =~ ~s(aircraft-class="military")
  end

  test "the legend counts aircraft" do
    html = render_map([plane(%{"hex" => "aaa"}), plane(%{"hex" => "bbb"})])

    assert html =~ "2 aircraft"
    assert html =~ "Aircraft"
  end

  test "the map centres on the aircraft when there is nothing else" do
    html = render_map([plane(%{"lat" => 51.47, "lon" => -0.45})])

    # not the empty-map fallback over Kansas
    refute html =~ ~s(lat="39.8283")
    assert html =~ ~s(lat="51.47")
  end

  test "no aircraft is not an error" do
    html = render_map([])

    refute html =~ ~s(type="aircraft")
    refute html =~ "aircraft)"
  end
end
