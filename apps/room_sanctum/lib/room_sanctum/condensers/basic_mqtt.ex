defmodule RoomSanctum.Condenser.BasicMQTT do
  alias RoomSanctum.Storage.AirNow.HourlyObsData
  import MapMerge

  defp gtfs_mode(route_type) do # todo move me
    case route_type do
      "0" -> "LightRail"
      "1" -> "Subway"
      "2" -> "Rail"
      "3" -> "Bus"
      "4" -> "Ferry"
      "5" -> "CableCar"
      "6" -> "Gondola"
      "7" -> "Funicular"
      "11" -> "Trolleybus"
      "12" -> "Monorail"
    end
  end

  defp wrap(item) do
    [item]
  end

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
            route: f.trip.route_id,
            mode: f.trip.route.route_type |> gtfs_mode
          }
        end)
        |> Enum.reduce(%{}, fn %{time: time, destination: dest, direction: dir, route: route, mode: mode}, acc ->
          update_in(acc, [{route, dest, dir}], fn
            nil -> %{route: route, dest: dest, dir: dir, mode: mode, times: [time]}
            refs -> %{refs | times: [time | refs.times]}
          end)
        end)
        |> Enum.map(fn {k,v} -> v |> Map.put(:times, v.times |> Enum.reverse) end)

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
        |> wrap

      :weather ->
        data
        |> Enum.map(fn f ->
          %{
            name: f.name,
            weather: List.first(f.weather).main,
            temp: f.main.temp,
            feel: f.main.feels_like,
            hum: f.main.humidity,
            pressure: f.main.pressure,
            wind: f.wind,
            visibility: f.visibility,
            units: f.units
          }
        end)

      :aqi ->
        data
        |> Enum.map(fn f ->
          pairs = HourlyObsData.compile_pairs(f)
          pairs ||| %{name: f.reporting_areas |> List.first()}
        end)

      :ephem ->
        data |> Enum.map(fn f ->
        case Map.get(f, :period) do
          nil -> {:name, f.name}
          val -> {f.period, f.result}
        end
        end) |> Enum.into(%{}) |> wrap

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
