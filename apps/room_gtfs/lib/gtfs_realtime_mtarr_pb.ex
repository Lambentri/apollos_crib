defmodule TransitRealtime.MtaRailroadCarriageDetails.QuietCarriage do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "transit_realtime.MtaRailroadCarriageDetails.QuietCarriage",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :UNKNOWN_QUIET_CARRIAGE, 0
  field :QUIET_CARRIAGE, 1
  field :NOT_QUIET_CARRIAGE, 2
end

defmodule TransitRealtime.MtaRailroadCarriageDetails.ToiletFacilities do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "transit_realtime.MtaRailroadCarriageDetails.ToiletFacilities",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :UNKNOWN_TOILET_FACILITIES, 0
  field :TOILET_ONBOARD, 1
  field :NO_TOILET_ONBOARD, 2
end

defmodule TransitRealtime.MtaRailroadStopTimeUpdate do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.MtaRailroadStopTimeUpdate",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :track, 1, optional: true, type: :string
  field :trainStatus, 2, optional: true, type: :string
end

defmodule TransitRealtime.MtaRailroadCarriageDetails do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.MtaRailroadCarriageDetails",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :bicycles_allowed, 1,
    optional: true,
    type: :int32,
    json_name: "bicyclesAllowed",
    default: 0

  field :carriage_class, 2, optional: true, type: :string, json_name: "carriageClass"

  field :quiet_carriage, 3,
    optional: true,
    type: TransitRealtime.MtaRailroadCarriageDetails.QuietCarriage,
    json_name: "quietCarriage",
    default: :UNKNOWN_QUIET_CARRIAGE,
    enum: true

  field :toilet_facilities, 4,
    optional: true,
    type: TransitRealtime.MtaRailroadCarriageDetails.ToiletFacilities,
    json_name: "toiletFacilities",
    default: :UNKNOWN_TOILET_FACILITIES,
    enum: true
end
