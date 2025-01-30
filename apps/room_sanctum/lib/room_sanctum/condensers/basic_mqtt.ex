defmodule RoomSanctum.Condenser.BasicMQTT do
  alias RoomSanctum.Storage.AirNow.HourlyObsData
  import MapMerge

  # todo move me
  defp gtfs_mode(route_type) do
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
      _ -> "Unknown"
    end
  end

  defp wrap(item) do
    [item]
  end

  defp time(datestr) do
    datestr |> Timex.parse!("{ISO:Extended}") |> Timex.format!("%H:%M", :strftime)
  end

  defp livetime(unix, _tz) when is_nil(unix) do
    unix
  end

  defp livetime(unix, tz) do
    unix |> DateTime.from_unix!() |> Timex.Timezone.convert(tz) |> DateTime.to_time()
  end

  def condense({_id, type}, data) do
    #    if type == :gtfs do
    #      IO.inspect({type, data})
    #    end

    case type do
      :gtfs ->
        data
        |> Enum.map(fn f ->
          %{
            time: f.arrival_time,
            time_live: f.arrival_time_live_ts,
            destination: f.trip.trip_headsign,
            direction: f.trip.direction.direction,
            route: f.trip.route_id,
            mode: f.trip.route.route_type |> gtfs_mode,
            tz: f.tz
          }
        end)
        |> Enum.reduce(%{}, fn %{
                                 time: time,
                                 time_live: time_live,
                                 destination: dest,
                                 direction: dir,
                                 route: route,
                                 mode: mode,
                                 tz: tz
                               },
                               acc ->
          update_in(acc, [{route, dest, dir}], fn
            nil ->
              %{
                route: route,
                dest: dest,
                dir: dir,
                mode: mode,
                times: [time],
                times_live: [livetime(time_live, tz)]
              }

            refs ->
              %{
                refs
                | times: [time | refs.times],
                  times_live: [livetime(time_live, tz) | refs.times_live]
              }
          end)
        end)
        |> Enum.map(fn {_k, v} ->
          case Enum.any?(v.times_live, fn x -> x != nil end) do
            true ->
              v
              |> Map.put(:times, v.times |> Enum.reverse())
              |> Map.put(:times_live, v.times_live |> Enum.reverse())

            false ->
              v |> Map.put(:times, v.times |> Enum.reverse()) |> Map.delete(:times_live)
          end
        end)

      :gbfs ->
        data
        |> Enum.map(fn f ->
          %{
            name: f.name,
            id: f.station_id,
            avail: f.num_bikes_available,
            avail_elec: f.num_ebikes_available,
            avail_std: f.num_bikes_available - f.num_ebikes_available,
            docks_avail: f.num_docks_available,
            docks_disabled: f.num_docks_disabled,
            capacity: f.capacity,
            ebikes_info: f.ebikes_info |> Enum.map(fn eb -> %{name: eb.displayed_number, battery_pct: eb.battery_charge_percentage, range_mi_cons: eb.range_estimate.conservative_range_miles, range_me_est: eb.range_estimate.estimated_range_miles} end)
          }
        end)

      :tidal ->
        data
        |> Enum.group_by(fn x -> x.type end)
        |> Enum.map(fn {extreme, data} ->
          case data do
            [first, second] ->
              k1 = "first_#{extreme |> String.downcase()}" |> String.to_atom()
              k2 = "second_#{extreme |> String.downcase()}" |> String.to_atom()
              kv1 = "first_#{extreme |> String.downcase()}v" |> String.to_atom()
              kv2 = "second_#{extreme |> String.downcase()}v" |> String.to_atom()
              %{k1 => first.t |> time, k2 => second.t |> time, kv1 => first.v, kv2 => second.v}

            [solo] ->
              k1 = "first_#{extreme |> String.downcase()}" |> String.to_atom()
              kv1 = "first_#{extreme |> String.downcase()}v" |> String.to_atom()
              %{k1 => solo.t |> time, kv1 => solo.v}
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
            visibility: f |> Map.get(:visibility),
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
        data
        |> Enum.map(fn f ->
          case Map.get(f, :period) do
            nil -> {:name, f.name}
            _val -> {f.period, f.result}
          end
        end)
        |> Enum.into(%{})
        |> wrap

      :calendar ->
        data
        |> Enum.map(fn f ->
          %{
            date_start: f.date_start |> DateTime.to_date(),
            description: f.blob["description"]
          }
        end)

      :cronos ->
        data

      :gitlab ->
        data

      :packages ->
        data

      :const ->
        data
    end
  end
end
