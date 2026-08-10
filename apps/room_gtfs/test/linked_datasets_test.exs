defmodule RoomGtfs.LinkedDatasetsTest do
  @moduledoc """
  linked_datasets.txt wires a GTFS feed to its own GTFS-RT endpoints. Publishers
  disagree on the spelling, so these are the shapes seen in the wild.
  """
  use ExUnit.Case, async: true

  describe "linked_datasets.txt" do
    test "reads MBTA's 1/0 flags across one row per feed" do
      csv = """
      url,trip_updates,vehicle_positions,service_alerts,authentication_type
      https://cdn.mbta.com/realtime/TripUpdates.pb,1,0,0,0
      https://cdn.mbta.com/realtime/VehiclePositions.pb,0,1,0,0
      https://cdn.mbta.com/realtime/Alerts.pb,0,0,1,0
      """

      urls = csv |> RoomGtfs.Worker.Static.parse_linked_datasets() |> RoomGtfs.Worker.Static.linked_dataset_urls()

      assert urls == %{
               url_rt_tu: "https://cdn.mbta.com/realtime/TripUpdates.pb",
               url_rt_vp: "https://cdn.mbta.com/realtime/VehiclePositions.pb",
               url_rt_sa: "https://cdn.mbta.com/realtime/Alerts.pb"
             }
    end

    test "reads Caltrain's true/false flags and extra columns" do
      csv = """
      url,trip_updates,vehicle_positions,service_alerts,authentication_type,authentication_info_url,api_key_parameter_name
      http://example.test/service_alerts.proto,false,false,true,none,,
      """

      urls = csv |> RoomGtfs.Worker.Static.parse_linked_datasets() |> RoomGtfs.Worker.Static.linked_dataset_urls()

      assert urls == %{url_rt_sa: "http://example.test/service_alerts.proto"}
    end

    test "a feed behind an api key is left alone" do
      csv = """
      url,trip_updates,vehicle_positions,service_alerts,authentication_type
      https://example.test/tu.pb,1,0,0,2
      https://example.test/vp.pb,0,1,0,0
      """

      urls = csv |> RoomGtfs.Worker.Static.parse_linked_datasets() |> RoomGtfs.Worker.Static.linked_dataset_urls()

      assert urls == %{url_rt_vp: "https://example.test/vp.pb"}
      refute Map.has_key?(urls, :url_rt_tu)
    end

    test "a header-only or empty file yields nothing" do
      assert RoomGtfs.Worker.Static.parse_linked_datasets("") |> RoomGtfs.Worker.Static.linked_dataset_urls() == %{}

      assert "url,trip_updates,vehicle_positions,service_alerts\n"
             |> RoomGtfs.Worker.Static.parse_linked_datasets()
             |> RoomGtfs.Worker.Static.linked_dataset_urls() == %{}
    end
  end
end
