defmodule RoomSanctum.Condenser.BasicMQTT do
  alias RoomSanctum.Storage.AirNow.HourlyObsData
  import MapMerge

  def condense({id, type}, data) do
    IO.inspect({id, type, data})

    case type do
      :gtfs ->
        data
        |> Enum.map(fn f ->
          %{time: f.arrival_time, destination: f.trip.trip_headsign, direction: f.trip.direction.direction, route: f.trip.route_id}
        end)
      :gbfs ->
        data
        |> Enum.map(fn f ->
          %{name: f.name, avail: f.num_bikes_available, capacity: f.capacity}
        end)

      :tidal ->
        :ok

      :weather ->
        data
        |> Enum.map(fn f ->
          %{
            name: f.name,
            weather: List.first(f.weather).main,
            temp: f.main.temp,
            feel: f.main.feels_like,
            hum: f.main.humidity,
            pressure: f.main.pressure
          }
        end)

      :aqi ->
        data
        |> Enum.map(fn f ->
          pairs = HourlyObsData.compile_pairs(f)
          pairs ||| %{name: f.reporting_areas |> List.first()}
        end)

      :ephem ->
        :ok

      :calendar ->
        :ok
    end
  end
end
