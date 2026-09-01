defmodule RoomSanctumWeb.GbfsPreviewTest do
  @moduledoc """
  An area query asked to include docks answers with two kinds of thing in one
  list. Everything that renders a gbfs answer has to cope with both, in the
  same list, in either order.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.LivePreview

  alias RoomSanctum.Condenser.BasicMQTT
  alias RoomSanctum.Storage.GBFS.V1.FreeBikeStatus

  defp bike(id) do
    %FreeBikeStatus{
      bike_id: id,
      lat: 37.75,
      lon: -122.41,
      is_disabled: false,
      is_reserved: false,
      current_range_meters: 12_000.0,
      current_fuel_percent: 0.62,
      vehicle_type_id: "scooter"
    }
  end

  defp dock(id) do
    %{
      station_id: id,
      name: "22nd St Caltrain Station",
      short_name: "22",
      capacity: 35,
      num_bikes_available: 13,
      num_ebikes_available: 10,
      num_docks_available: 21,
      num_docks_disabled: 0,
      ebikes_info: []
    }
  end

  defp condensed(entries), do: %{data: BasicMQTT.condense_data({1, :gbfs}, entries)}

  test "the condenser tells a bike from a dock by what came back" do
    kinds =
      BasicMQTT.condense_data({1, :gbfs}, [bike("b1"), dock("s1")])
      |> Enum.map(&Map.get(&1, :kind, :station))

    assert kinds == [:free_bike, :station]
  end

  test "the preview card renders a mixed answer" do
    html = render_component(&p_gbfs/1, entries: condensed([bike("b1"), dock("s1")]))

    # The bike, by charge and range.
    assert html =~ "62%"
    assert html =~ "12.0 km"
    # The dock, by what is in it: the card counts standard bikes separately
    # from electric ones, so 13 available with 10 electric reads as 3 and 10.
    assert html =~ "22nd St Caltrain Station"
    assert html =~ "> 3\n"
    assert html =~ "10"
    assert html =~ "35"
  end

  test "the display card renders a mixed answer, in either order" do
    html = render_component(&i_gbfs/1, entries: condensed([dock("s1"), bike("b1")]))

    assert html =~ "22nd St Caltrain"
    assert html =~ "62%"
  end

  test "a bike-only answer still renders where a dock's fields are missing" do
    assert render_component(&p_gbfs/1, entries: condensed([bike("b1")])) =~ "62%"
    assert render_component(&i_gbfs/1, entries: condensed([bike("b1")])) =~ "12.0 km"
  end

  test "a dock-only answer is unchanged" do
    html = render_component(&p_gbfs/1, entries: condensed([dock("s1")]))

    assert html =~ "22nd St Caltrain Station"
    refute html =~ "km"
  end
end
