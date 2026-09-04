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

  @doc """
  What a route is called and what colour it is, from the static feed.

  Both are already sitting in the arrival row and cost nothing to carry. The
  raw id is an internal string -- MBTA's "Orange" reads fine, NYCT's
  "1" less so, and plenty of agencies use an opaque number -- while
  `route_short_name` is what is written on the front of the vehicle. The id is
  still published alongside this, because it is what anything downstream keys
  on.

  GTFS stores colours bare ("FFC72C"); CSS wants the hash, so it is added here
  rather than at each of the places that draw one.
  """
  def route_presentation(route, route_id) do
    # Read rather than matched: a feed mid-refresh, or a caller assembling a
    # route by hand, can hand over a map with only some of these. A missing
    # column is a route with no name and no colour, not a crash -- and the
    # callers that draw this swallow exceptions, so raising here would blank a
    # map popup rather than report anything.
    %{
      route_name:
        presence(Map.get(route, :route_short_name)) ||
          presence(Map.get(route, :route_long_name)) ||
          route_id,
      route_long: presence(Map.get(route, :route_long_name)),
      color: hex(Map.get(route, :route_color)),
      text_color: hex(Map.get(route, :route_text_color))
    }
  end

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(value), do: value

  defp hex(nil), do: nil
  defp hex(""), do: nil
  defp hex("#" <> _ = color), do: color
  defp hex(color), do: "#" <> color

  defp time(datestr) do
    datestr |> Timex.parse!("{ISO:Extended}") |> Timex.format!("%H:%M", :strftime)
  end

  defp livetime(unix, _tz) when is_nil(unix) do
    unix
  end

  defp livetime(unix, tz) do
    unix |> DateTime.from_unix!() |> Timex.Timezone.convert(tz) |> DateTime.to_time()
  end

  @doc """
  Condenses data without wrapping (legacy format)
  """
  def condense_data({_id, type}, data) when data == [], do: %{}
  def condense_data({_id, type}, data) do
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
            presentation: route_presentation(f.trip.route, f.trip.route_id),
            mode: f.trip.route.route_type |> gtfs_mode,
            tz: f.tz,
            bearing: Map.get(f, :bearing)
          }
        end)
        |> Enum.reduce(%{}, fn %{
                                 time: time,
                                 time_live: time_live,
                                 destination: dest,
                                 direction: dir,
                                 route: route,
                                 presentation: presentation,
                                 mode: mode,
                                 tz: tz,
                                 bearing: bearing
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
                times_live: [livetime(time_live, tz)],
                bearing: bearing
              }
              |> Map.merge(presentation)

            refs ->
              %{
                refs
                | times: [time | refs.times],
                  times_live: [livetime(time_live, tz) | refs.times_live],
                  # A blended Plani groups a route across every stop it calls
                  # at inside the radius, so these times can come from two
                  # places at once. Agreeing keeps the bearing; disagreeing
                  # drops it, because "north east" would then be true of only
                  # some of the departures under it.
                  bearing: if(refs.bearing == bearing, do: bearing, else: nil)
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
        # Only a Plani has a bearing to give, and only for a stop far enough
        # away to have one. Dropped rather than published as null, so a
        # vision's payload is byte for byte what it always was.
        |> Enum.map(fn route ->
          if route.bearing, do: route, else: Map.delete(route, :bearing)
        end)

      :gbfs ->
        # A bike names its type by an id of the feed's own choosing -- Bay
        # Wheels' e-bike is "2" -- so the types are resolved once for the list
        # rather than every bike being labelled with a number.
        vehicle_types = gbfs_vehicle_types(data)

        data
        |> Enum.map(fn
          # An area query answers with loose bikes rather than a dock, and a
          # bike has none of a station's fields -- no name, no capacity,
          # nothing to dock. Told apart by what came back rather than by the
          # query, since the condenser is only ever handed the answer.
          %{bike_id: bike_id} = b ->
            %{
              kind: :free_bike,
              name: vehicle_label(vehicle_types, b) || bike_id,
              # What kind of thing it is, so a client can draw a car as a car.
              # The name already says "Car", but a name is read and an icon is
              # glanced at, and these cards are built to be glanced at.
              form_factor: vehicle_form_factor(vehicle_types, b),
              id: bike_id,
              lat: b.lat,
              lon: b.lon,
              range_m: b.current_range_meters,
              fuel_pct: b.current_fuel_percent,
              reserved: b.is_reserved,
              disabled: b.is_disabled
            }
            |> with_dir(b)

          f ->
            %{
              name: f.name,
              id: f.station_id,
              avail: f.num_bikes_available,
              avail_elec: f.num_ebikes_available,
              # Same reasoning: a feed that does not break its count down by
              # motor leaves these null, and subtracting one raises.
              avail_std: (f.num_bikes_available || 0) - (f.num_ebikes_available || 0),
              docks_avail: f.num_docks_available,
              docks_disabled: f.num_docks_disabled,
              capacity: f.capacity,
              ebikes_info:
                # A left join, so a dock that no e-bike is sitting in comes
                # back nil rather than empty -- and mapping over that raised,
                # which killed the condense for the *whole* board rather than
                # this one dock. A Plani feels it hardest: it breaks a source
                # out into an entry per dock, so a radius holding one ordinary
                # unelectrified dock published nothing at all.
                (f.ebikes_info || [])
                |> Enum.map(fn eb ->
                  %{
                    name: eb.displayed_number,
                    battery_pct: eb.battery_charge_percentage,
                    range_mi_cons: eb.range_estimate.conservative_range_miles,
                    range_me_est: eb.range_estimate.estimated_range_miles
                  }
                end)
            }
            |> with_dir(f)
        end)

      :tidal ->
        data
        |> IO.inspect
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

      :github ->
        data

      :drought ->
        data

      :pollen ->
        data

      :icarus ->
        data

      :mailbox ->
        data

      :treasury ->
        data

      :bourse ->
        data

      :packages ->
        data

      :const ->
        data
    end
  end

  @doc """
  Condenses data and wraps it with query information
  """
  def condense({id, :gtfs}, data, query) do
    condensed = condense_data({id, :gtfs}, data)
    route_ids = condensed |> Enum.map(& &1.route) |> Enum.uniq()
    # An area query has no one stop, so there is no stop-specific alert to
    # look for -- only the ones on the routes that turned up.
    stop      = Map.get(query.query, :stop)
    # A broken out entry is keyed by source *and* stop, so its id is not a
    # source id and the lookup found nothing -- silently, since no alerts and
    # no such source look the same from here. The descriptor names the source
    # when the key cannot.
    source_id = Map.get(query.query, :source_id) || id
    alerts    = RoomGtfs.Worker.query_alerts(source_id, stop, route_ids)

    condensed_with_alerts = condensed |> Enum.map(fn route ->
      route_alerts = Enum.filter(alerts, fn a ->
        a.route_id == nil || a.route_id == route.route
      end)
      case route_alerts do
        [] -> route
        _  -> Map.put(route, :alerts, route_alerts)
      end
    end)

    %{
      data: condensed_with_alerts,
      query: %{name: query.name, meta: query.meta || %{}}
    }
  end

  def condense({id, type}, data, query) do
    condensed_data = condense_data({id, type}, data)

    %{
      data: condensed_data,
      query: %{
        name: query.name,
        meta: query.meta || %{}
      }
    }
  end

  # Which way the thing lies from where the reader is standing.
  #
  # Only a Plani stamps this -- it is the one field here that is relative to
  # the reader rather than to the world, and a vision's foci is a fixed place
  # whose directions never change. Left out entirely rather than published as
  # null, so a vision's payload is byte for byte what it always was.
  defp with_dir(condensed, row) do
    case Map.get(row, :dir) do
      nil -> condensed
      dir -> Map.put(condensed, :dir, dir)
    end
  end

  # The vehicle types behind a list of bikes, or an empty map for a list that
  # holds none -- a station answer, or a source whose vehicle_types.json has
  # not been read yet.
  defp gbfs_vehicle_types(data) do
    data
    |> Enum.flat_map(fn
      %{bike_id: _, source_id: source_id} when not is_nil(source_id) -> [source_id]
      _ -> []
    end)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn source_id, acc ->
      Map.merge(acc, RoomSanctum.Storage.gbfs_vehicle_types(source_id))
    end)
  end

  # Straight off the vehicle type, in GBFS's own words -- "car", "moped",
  # "scooter_standing". Left untranslated because the client is choosing a
  # glyph from it rather than showing it.
  defp vehicle_form_factor(vehicle_types, bike) do
    case Map.get(vehicle_types, Map.get(bike, :vehicle_type_id)) do
      %{form_factor: form_factor} -> form_factor
      _ -> nil
    end
  end

  defp vehicle_label(vehicle_types, bike) do
    vehicle_types
    |> Map.get(Map.get(bike, :vehicle_type_id))
    |> RoomSanctum.Storage.GBFS.V1.VehicleTypes.label()
  end

end
