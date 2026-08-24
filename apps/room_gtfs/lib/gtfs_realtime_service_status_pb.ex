defmodule TransitRealtime.MercuryEntitySelector.Priority do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "transit_realtime.MercuryEntitySelector.Priority",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :PRIORITY_NO_SCHEDULED_SERVICE, 1
  field :PRIORITY_INFORMATION_OUTAGE, 2
  field :PRIORITY_STATION_NOTICE, 3
  field :PRIORITY_SPECIAL_NOTICE, 4
  field :PRIORITY_WEEKDAY_SCHEDULE, 5
  field :PRIORITY_WEEKEND_SCHEDULE, 6
  field :PRIORITY_SATURDAY_SCHEDULE, 7
  field :PRIORITY_SUNDAY_SCHEDULE, 8
  field :PRIORITY_EXTRA_SERVICE, 9
  field :PRIORITY_BOARDING_CHANGE, 10
  field :PRIORITY_SPECIAL_SCHEDULE, 11
  field :PRIORITY_EXPECT_DELAYS, 12
  field :PRIORITY_REDUCED_SERVICE, 13
  field :PRIORITY_PLANNED_EXPRESS_TO_LOCAL, 14
  field :PRIORITY_PLANNED_EXTRA_TRANSFER, 15
  field :PRIORITY_PLANNED_STOPS_SKIPPED, 16
  field :PRIORITY_PLANNED_DETOUR, 17
  field :PRIORITY_PLANNED_REROUTE, 18
  field :PRIORITY_PLANNED_SUBSTITUTE_BUSES, 19
  field :PRIORITY_PLANNED_PART_SUSPENDED, 20
  field :PRIORITY_PLANNED_SUSPENDED, 21
  field :PRIORITY_SERVICE_CHANGE, 22
  field :PRIORITY_PLANNED_WORK, 23
  field :PRIORITY_SOME_DELAYS, 24
  field :PRIORITY_EXPRESS_TO_LOCAL, 25
  field :PRIORITY_DELAYS, 26
  field :PRIORITY_CANCELLATIONS, 27
  field :PRIORITY_DELAYS_AND_CANCELLATIONS, 28
  field :PRIORITY_STOPS_SKIPPED, 29
  field :PRIORITY_SEVERE_DELAYS, 30
  field :PRIORITY_DETOUR, 31
  field :PRIORITY_REROUTE, 32
  field :PRIORITY_SUBSTITUTE_BUSES, 33
  field :PRIORITY_PART_SUSPENDED, 34
  field :PRIORITY_SUSPENDED, 35
end

defmodule TransitRealtime.MercuryFeedHeader do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.MercuryFeedHeader",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :mercury_version, 1, required: true, type: :string, json_name: "mercuryVersion"
end

defmodule TransitRealtime.MercuryStationAlternative do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.MercuryStationAlternative",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :affected_entity, 1,
    required: true,
    type: TransitRealtime.EntitySelector,
    json_name: "affectedEntity"

  field :notes, 2, required: true, type: TransitRealtime.TranslatedString
end

defmodule TransitRealtime.MercuryAlert do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.MercuryAlert",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :created_at, 1, required: true, type: :uint64, json_name: "createdAt"
  field :updated_at, 2, required: true, type: :uint64, json_name: "updatedAt"
  field :alert_type, 3, required: true, type: :string, json_name: "alertType"

  field :station_alternative, 4,
    repeated: true,
    type: TransitRealtime.MercuryStationAlternative,
    json_name: "stationAlternative"

  field :service_plan_number, 5, repeated: true, type: :string, json_name: "servicePlanNumber"
  field :general_order_number, 6, repeated: true, type: :string, json_name: "generalOrderNumber"
  field :display_before_active, 7, optional: true, type: :uint64, json_name: "displayBeforeActive"

  field :human_readable_active_period, 8,
    optional: true,
    type: TransitRealtime.TranslatedString,
    json_name: "humanReadableActivePeriod"

  field :directionality, 9, optional: true, type: :uint64

  field :affected_stations, 10,
    repeated: true,
    type: TransitRealtime.EntitySelector,
    json_name: "affectedStations"

  field :screens_summary, 11,
    optional: true,
    type: TransitRealtime.TranslatedString,
    json_name: "screensSummary"

  field :no_affected_stations, 12, optional: true, type: :bool, json_name: "noAffectedStations"
  field :clone_id, 13, optional: true, type: :string, json_name: "cloneId"
end

defmodule TransitRealtime.MercuryEntitySelector do
  @moduledoc false

  use Protobuf,
    full_name: "transit_realtime.MercuryEntitySelector",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto2

  field :sort_order, 1, required: true, type: :string, json_name: "sortOrder"
end
