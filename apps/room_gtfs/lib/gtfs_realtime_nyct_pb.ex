defmodule TransitRealtime.NyctTripDescriptor.Direction do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "transit_realtime.NyctTripDescriptor.Direction",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :NORTH, 1
  field :EAST, 2
  field :SOUTH, 3
  field :WEST, 4
end

defmodule TransitRealtime.TripReplacementPeriod do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.TripReplacementPeriod",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :route_id, 1, optional: true, type: :string, json_name: "routeId"

  field :replacement_period, 2,
    optional: true,
    type: TransitRealtime.TimeRange,
    json_name: "replacementPeriod"
end

defmodule TransitRealtime.NyctFeedHeader do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.NyctFeedHeader",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :nyct_subway_version, 1, required: true, type: :string, json_name: "nyctSubwayVersion"

  field :trip_replacement_period, 2,
    repeated: true,
    type: TransitRealtime.TripReplacementPeriod,
    json_name: "tripReplacementPeriod"
end

defmodule TransitRealtime.NyctTripDescriptor do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.NyctTripDescriptor",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :train_id, 1, optional: true, type: :string, json_name: "trainId"
  field :is_assigned, 2, optional: true, type: :bool, json_name: "isAssigned"

  field :direction, 3,
    optional: true,
    type: TransitRealtime.NyctTripDescriptor.Direction,
    enum: true
end

defmodule TransitRealtime.NyctStopTimeUpdate do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.NyctStopTimeUpdate",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :scheduled_track, 1, optional: true, type: :string, json_name: "scheduledTrack"
  field :actual_track, 2, optional: true, type: :string, json_name: "actualTrack"
end
