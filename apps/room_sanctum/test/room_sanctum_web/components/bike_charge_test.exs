defmodule RoomSanctumWeb.BikeChargeTest do
  @moduledoc """
  A bike marker is shaded by how full it is, so the charge has to reach the
  marker -- and the number has to reach the popup, since a shade alone is not
  a reading.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Storage.GBFS.V1.FreeBikeStatus
  alias RoomSanctum.Storage.GBFS.V1.VehicleTypes

  defp bike(opts) do
    %FreeBikeStatus{
      bike_id: Keyword.get(opts, :id, "b1"),
      lat: 37.75,
      lon: -122.41,
      is_disabled: Keyword.get(opts, :disabled, false),
      is_reserved: Keyword.get(opts, :reserved, false),
      current_range_meters: Keyword.get(opts, :range),
      current_fuel_percent: Keyword.get(opts, :fuel),
      vehicle_type_id: "scooter"
    }
  end

  defp map_html(bikes) do
    render_component(&query_geospatial_map/1, queries: [], free_bikes: bikes, id: "t")
  end

  test "a bike is named for what it is, not for the feed's id for it" do
    # Bay Wheels calls its e-bike type "2". Every bike in that feed carried the
    # name "2" until the type was resolved.
    assert VehicleTypes.label(%{form_factor: "bicycle", propulsion_type: "electric_assist"}) ==
             "E-bike"

    assert VehicleTypes.label(%{form_factor: "bicycle", propulsion_type: "human"}) == "Bike"
    assert VehicleTypes.label(%{form_factor: "scooter_standing", propulsion_type: "electric"}) ==
             "Scooter"
  end

  test "a form factor the spec adds later still reads as words" do
    assert VehicleTypes.label(%{form_factor: "hovercraft", propulsion_type: "electric"}) ==
             "Electric hovercraft"

    assert VehicleTypes.label(%{form_factor: nil, propulsion_type: "electric"}) == nil
    assert VehicleTypes.label(nil) == nil
  end

  test "range is read against the furthest these feeds report" do
    # With no vehicle types published, 60km is the fallback ceiling, so 30km is
    # half.
    assert map_html([bike(range: 30_000.0)]) =~ ~s(charge="50")
    assert map_html([bike(range: 60_000.0)]) =~ ~s(charge="100")
  end

  test "a range beyond the ceiling clamps rather than overflowing the ramp" do
    assert map_html([bike(range: 120_000.0)]) =~ ~s(charge="100")
  end

  test "fuel percent wins over range, and is read on either scale it arrives in" do
    # GBFS says 0..1; feeds send 0..100 anyway. Both mean the same bike here.
    assert map_html([bike(fuel: 0.62, range: 1_000.0)]) =~ ~s(charge="62")
    assert map_html([bike(fuel: 62.0, range: 1_000.0)]) =~ ~s(charge="62")
  end

  test "a bike reporting neither carries no charge at all, rather than a zero" do
    html = map_html([bike(id: "unknown")])

    refute html =~ "charge="
  end

  test "the popup carries the number, so the shade is never the only reading" do
    html = map_html([bike(fuel: 0.62, range: 12_000.0)])

    assert html =~ "Charge"
    assert html =~ "62%"
    assert html =~ "12.0 km"
  end

  test "a bike out of service says so" do
    assert map_html([bike(range: 1_000.0, disabled: true)]) =~ "Out of service"
    assert map_html([bike(range: 1_000.0, reserved: true)]) =~ "Reserved"
  end

  test "the legend explains the shading whenever bikes are on the map" do
    html = map_html([bike(range: 1_000.0)])

    # Every step of the ramp, and the neutral for an unknown charge.
    for step <- ~w(#22c55e #16a34a #15803d #14532d #898781) do
      assert html =~ step
    end
  end

  test "no bikes, no charge key" do
    refute render_component(&query_geospatial_map/1, queries: [], id: "t") =~ "#898781"
  end
end
