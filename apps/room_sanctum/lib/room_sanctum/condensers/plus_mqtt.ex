defmodule RoomSanctum.Condenser.PlusMQTT do
  @moduledoc """
  The extended read of a query's answer -- everything Basic says, and the rest
  of what the feed reported alongside it.

  Basic condenses an arrival down to a time, because that is what a card has
  room for. GTFS-RT carries more than that: how full the vehicle is, how far
  off schedule, how sure the feed is of its own estimate. Plus keeps each
  arrival whole rather than flattening it into parallel lists, so the view can
  say all of it about the arrival it belongs to.

  Only the types with more to say are written here; everything else is Basic's
  answer, unchanged.
  """

  alias RoomSanctum.Condenser.BasicMQTT

  @doc """
  Condenses data without wrapping (legacy format)
  """
  def condense_data({_id, _type}, data) when data == [], do: %{}

  def condense_data({id, :gtfs}, data) do
    data
    |> Enum.map(fn f ->
      %{
        key: {f.trip.route_id, f.trip.trip_headsign, f.trip.direction.direction},
        mode: f.trip.route.route_type |> gtfs_mode(),
        presentation: BasicMQTT.route_presentation(f.trip.route, f.trip.route_id),
        arrival: %{
          time: f.arrival_time,
          time_live: livetime(f.arrival_time_live_ts, f.tz),
          delay: Map.get(f, :arrival_time_live_delay),
          uncertainty: Map.get(f, :arrival_time_live_uncertianty),
          occupancy: Map.get(f, :occupancy),
          occupancy_pct: Map.get(f, :occupancy_pct),
          # The number written on the side of the train, where a feed gives one.
          name: f.trip.trip_short_name,
          bikes: f.trip.bikes_allowed,
          carriages: Map.get(f, :carriages, []),
          # Not running, or running but not calling here -- kept apart,
          # because they are different news to a rider.
          trip_status: Map.get(f, :trip_status),
          stop_status: Map.get(f, :stop_status),
          # What this call says about itself, over what the trip says.
          headsign: Map.get(f, :stop_headsign),
          platform: Map.get(f, :assigned_platform),
          trip_id: f.trip_id
        }
      }
    end)
    |> Enum.reduce(%{}, fn %{
                             key: {route, dest, dir} = key,
                             mode: mode,
                             presentation: presentation,
                             arrival: arrival
                           },
                           acc ->
      update_in(acc, [key], fn
        nil ->
          %{route: route, dest: dest, dir: dir, mode: mode, arrivals: [arrival]}
          |> Map.merge(presentation)

        refs ->
          %{refs | arrivals: [arrival | refs.arrivals]}
      end)
    end)
    |> Enum.map(fn {_k, v} -> Map.put(v, :arrivals, v.arrivals |> Enum.reverse()) end)
    |> attach_alerts(id, stop_of(data))
  end

  def condense_data({id, type}, data), do: BasicMQTT.condense_data({id, type}, data)

  @doc """
  Condenses data and wraps it with query information
  """
  def condense({id, :gtfs}, data, query) do
    %{
      data: condense_data({id, :gtfs}, data),
      query: %{name: query.name, meta: query.meta || %{}}
    }
  end

  def condense({id, type}, data, query), do: BasicMQTT.condense({id, type}, data, query)

  # What is in force at this stop, on the routes calling at it.
  #
  # Attached in condense_data rather than only in the wrapped condense/3, so
  # the preview shows them too -- an alert nobody sees until the data reaches
  # MQTT is an alert doing nothing. The stop comes from the arrivals rather
  # than from the query, because they are all arrivals at one stop and the
  # preview has no query to read.
  defp attach_alerts(routes, nil, _stop), do: routes
  defp attach_alerts(routes, _id, nil), do: routes

  defp attach_alerts(routes, id, stop) do
    route_ids = routes |> Enum.map(& &1.route) |> Enum.uniq()

    case RoomGtfs.Worker.query_alerts(id, stop, route_ids) do
      [] ->
        routes

      alerts ->
        Enum.map(routes, fn route ->
          # An alert naming no route is agency-wide and applies to all of them.
          case Enum.filter(alerts, &(&1.route_id == nil or &1.route_id == route.route)) do
            [] -> route
            found -> Map.put(route, :alerts, found)
          end
        end)
    end
  end

  defp stop_of(data) do
    data |> Enum.find_value(&Map.get(&1, :stop_id))
  end

  # todo move me -- same table as Basic's, kept here rather than reaching into
  # a private function of another condenser.
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

  defp livetime(nil, _tz), do: nil

  defp livetime(unix, tz) do
    unix |> DateTime.from_unix!() |> Timex.Timezone.convert(tz) |> DateTime.to_time()
  end
end
