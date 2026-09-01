defmodule RoomSanctumWeb.OccupancyTest do
  @moduledoc """
  Occupancy is optional in GTFS-RT, and most feeds do not send it. The view has
  to draw nothing for those without noticing the difference.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RoomSanctumWeb.LivePreview

  defp dots(status, pct \\ nil) do
    render_component(&occupancy/1, status: status, pct: pct)
  end

  defp counts(html) do
    {String.split(html, "fa-solid fa-circle") |> length() |> Kernel.-(1),
     String.split(html, "fa-regular fa-circle") |> length() |> Kernel.-(1)}
  end

  test "a feed that says nothing draws nothing" do
    assert dots(nil) |> String.trim() == ""
  end

  test "a status nobody has heard of draws nothing" do
    assert dots(:SOMETHING_NEW) |> String.trim() == ""
  end

  test "the circles fill as the vehicle does" do
    assert counts(dots(:EMPTY)) == {0, 3}
    assert counts(dots(:MANY_SEATS_AVAILABLE)) == {1, 2}
    assert counts(dots(:FEW_SEATS_AVAILABLE)) == {2, 1}
    assert counts(dots(:STANDING_ROOM_ONLY)) == {3, 0}
  end

  test "green up to standing room, amber crushed, red full" do
    assert dots(:STANDING_ROOM_ONLY) =~ "text-green-500"
    assert dots(:CRUSHED_STANDING_ROOM_ONLY) =~ "text-amber-500"
    assert dots(:FULL) =~ "text-red-500"
  end

  test "a vehicle nobody may board is drawn, greyed, rather than left blank" do
    for status <- [:NOT_ACCEPTING_PASSENGERS, :NOT_BOARDABLE] do
      html = dots(status)
      assert counts(html) == {0, 3}
      assert html =~ "text-gray-400"
    end
  end

  describe "carriages" do
    defp strip(carriages) do
      render_component(&RoomSanctumWeb.LivePreview.carriages/1, carriages: carriages)
    end

    defp car(seq, occupancy), do: %{sequence: seq, label: nil, occupancy: occupancy, occupancy_pct: nil}

    test "a vehicle reporting no carriages draws no train" do
      assert strip([]) |> String.trim() == ""
    end

    test "each carriage is drawn, shaded by how full it is" do
      html = strip([car(1, :EMPTY), car(2, :FULL), car(3, :CRUSHED_STANDING_ROOM_ONLY)])

      assert html =~ "bg-green-200"
      assert html =~ "bg-red-500"
      assert html =~ "bg-amber-500"
    end

    test "a carriage with no data is hollow, not missing" do
      html = strip([car(1, :EMPTY), car(2, nil)])

      assert html =~ "border border-gray-400"
      assert length(String.split(html, "rounded-sm")) - 1 == 2
    end

    test "hovering names each carriage and its state" do
      html = strip([car(1, :EMPTY), car(2, nil)])

      assert html =~ "car 1: empty"
      assert html =~ "car 2: no data"
    end
  end

  describe "arrival flags" do
    import RoomSanctumWeb.LivePreview, only: [arrival_flag: 1]

    test "an ordinary arrival is not flagged" do
      assert arrival_flag(%{trip_status: nil, stop_status: nil}) == nil
    end

    test "a cancelled trip and a skipped stop read differently" do
      assert arrival_flag(%{trip_status: :CANCELED, stop_status: nil}) == "cancelled"
      assert arrival_flag(%{trip_status: nil, stop_status: :SKIPPED}) == "not stopping"
    end

    test "a trip that was not in the schedule says it is extra" do
      assert arrival_flag(%{trip_status: :ADDED, stop_status: nil}) == "extra"
    end
  end

  describe "route badge" do
    defp badge(entry, opts \\ []) do
      render_component(
        &RoomSanctumWeb.LivePreview.route_badge/1,
        Keyword.merge([entry: entry], opts)
      )
    end

    test "the route is drawn by its name, not its internal id" do
      html = badge(%{route: "r_9931", route_name: "22", color: nil, text_color: nil})

      assert html =~ "22"
      refute html =~ "r_9931"
    end

    test "an entry with no name at all falls back to the id" do
      assert badge(%{route: "r_9931"}) =~ "r_9931"
    end

    test "the line's colour fills the badge, with the agency's text colour on it" do
      html = badge(%{route: "22", route_name: "22", color: "#FFC72C", text_color: "#000000"})

      assert html =~ "background-color: #FFC72C"
      assert html =~ "color: #000000"
    end

    test "black is assumed by nobody: a colour with no text colour gets white" do
      assert badge(%{route: "22", route_name: "22", color: "#003DA5"}) =~ "color: #FFFFFF"
    end

    test "a feed with no colours leaves the card's own styling alone" do
      html = badge(%{route: "22", route_name: "22", color: nil})

      refute html =~ "background-color"
      refute html =~ "border-0"
    end
  end

  describe "alert badges" do
    import RoomSanctumWeb.LivePreview, only: [alert_label: 1]

    defp alert(attrs) do
      Map.merge(
        %{effect: "DETOUR", severity: "WARNING", header: "Shuttle buses", description: "",
          stop_specific: false, route_id: "22"},
        Map.new(attrs)
      )
    end

    defp alert_badge(alert) do
      render_component(&RoomSanctumWeb.LivePreview.x_gtfs/1,
        entries: %{
          data: [
            %{route: "22", route_name: "22", color: nil, dest: "Downtown", mode: "Bus",
              arrivals: [], alerts: [alert]}
          ]
        }
      )
    end

    test "the effect is the label, in words" do
      assert alert_label(%{effect: "NO_SERVICE"}) == "no service"
      assert alert_label(%{effect: "SIGNIFICANT_DELAYS"}) == "significant delays"
    end

    test "an effect the publisher never set is just an alert" do
      assert alert_label(%{effect: "UNKNOWN_EFFECT"}) == "alert"
      assert alert_label(%{effect: nil}) == "alert"
      assert alert_label(%{}) == "alert"
    end

    test "severity picks the colour" do
      assert alert_badge(alert(severity: "SEVERE")) =~ "badge-error"
      assert alert_badge(alert(severity: "WARNING")) =~ "badge-warning"
      assert alert_badge(alert(severity: "INFO")) =~ "badge-info"
      assert alert_badge(alert(severity: "UNKNOWN_SEVERITY")) =~ "badge-ghost"
    end

    test "an alert naming this stop is marked as being about this stop" do
      assert alert_badge(alert(stop_specific: true)) =~ "fa-location-dot"
      assert alert_badge(alert(stop_specific: false)) =~ "fa-triangle-exclamation"
    end

    test "the whole text is the hover, since a badge has no room for it" do
      html = alert_badge(alert(header: "Elevator out", description: "Use the ramp"))

      assert html =~ "Elevator out -- Use the ramp"
      assert html =~ "detour"
    end

    test "a route with nothing in force draws no badges" do
      html =
        render_component(&RoomSanctumWeb.LivePreview.x_gtfs/1,
          entries: %{
            data: [
              %{route: "22", route_name: "22", color: nil, dest: "Downtown", mode: "Bus",
                arrivals: []}
            ]
          }
        )

      refute html =~ "badge-warning"
      refute html =~ "fa-triangle-exclamation"
    end
  end

  test "the percentage joins the status when the feed sent one" do
    assert dots(:FULL, 95) =~ "full (95%)"
    assert dots(:FULL) =~ ~s(title="full")
  end
end
