defmodule TransitRealtime.PbExtension do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.17.0"

  extend TransitRealtime.TripDescriptor, :nyct_trip_descriptor, 1001,
    optional: true,
    type: TransitRealtime.NyctTripDescriptor,
    json_name: "nyctTripDescriptor"

  extend TransitRealtime.TripUpdate.StopTimeUpdate, :nyct_stop_time_update, 1001,
    optional: true,
    type: TransitRealtime.NyctStopTimeUpdate,
    json_name: "nyctStopTimeUpdate"

  extend TransitRealtime.TripUpdate.StopTimeUpdate, :mta_railroad_stop_time_update, 1005,
    optional: true,
    type: TransitRealtime.MtaRailroadStopTimeUpdate,
    json_name: "mtaRailroadStopTimeUpdate"

  extend TransitRealtime.VehiclePosition.CarriageDetails, :mta_railroad_carriage_details, 1005,
    optional: true,
    type: TransitRealtime.MtaRailroadCarriageDetails,
    json_name: "mtaRailroadCarriageDetails"

  extend TransitRealtime.Alert, :mercury_alert, 1001,
    optional: true,
    type: TransitRealtime.MercuryAlert,
    json_name: "mercuryAlert"

  extend TransitRealtime.EntitySelector, :mercury_entity_selector, 1001,
    optional: true,
    type: TransitRealtime.MercuryEntitySelector,
    json_name: "mercuryEntitySelector"
end
