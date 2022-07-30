defmodule RoomSanctum.Condenser.BasicMQTT do
  alias RoomSanctum.Storage.AirNow.HourlyObsData
  import MapMerge

  def condense({id, type}, data) do
#    if type == :tidal do
#      IO.inspect({id, type, data})
#    end

    case type do
      :gtfs ->
        data
        |> Enum.map(fn f ->
          %{
            time: f.arrival_time,
            destination: f.trip.trip_headsign,
            direction: f.trip.direction.direction,
            route: f.trip.route_id
          }
        end)
        |> Enum.reduce(%{}, fn %{time: time, destination: dest, direction: dir, route: route}, acc ->
          update_in(acc, [{route, dest, dir}], fn
            nil -> %{route: route, dest: dest, dir: dir, times: [time]}
            refs -> %{refs | times: [time | refs.times]}
          end)
        end)
        |> Enum.map(fn {k,v} -> v end)

      :gbfs ->
        data
        |> Enum.map(fn f ->
          %{name: f.name, avail: f.num_bikes_available, capacity: f.capacity}
        end)

      :tidal ->
        data
        |> Enum.group_by(fn x -> x.type end)
        |> Enum.map(fn {extreme, data} ->
        case data do
          [first, second] ->
            [first, second] = data
            k1 = "first_#{extreme |> String.downcase()}" |> String.to_atom()
            k2 = "second_#{extreme |> String.downcase()}" |> String.to_atom()
            kv1 = "first_#{extreme |> String.downcase()}v" |> String.to_atom()
            kv2 = "second_#{extreme |> String.downcase()}v" |> String.to_atom()
            %{k1 => first.t, k2 => second.t, kv1 => first.v, kv2 => second.v}
          [solo] ->
            k1 = "first_#{extreme |> String.downcase()}" |> String.to_atom()
            kv1 = "first_#{extreme |> String.downcase()}v" |> String.to_atom()
            %{k1 => solo.t, kv1 => solo.v}
        end
        end)
        |> Enum.reduce(&Map.merge/2)

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
        data |> Enum.map(fn f -> {f.period, f.result} end) |> Enum.into(%{})

      :calendar ->
        data
        |> Enum.map(fn f ->
          %{
            date_start: f.date_start |> DateTime.to_date(),
            description: f.blob["description"]
          }
        end)
    end
  end
end
