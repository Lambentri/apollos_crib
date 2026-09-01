defmodule RoomSanctumWeb.Live.Helpers.MapData do
  @moduledoc """
  The live layers a query map draws on top of its query markers: aircraft,
  air-quality stations and vehicle positions.

  A query marker says where a query *is*; these say what it currently sees.
  Both the single-query view and a vision's map view want them, computed the
  same way -- a vision is a handful of queries, so it asks for the same three
  things once per query and concatenates.
  """

  alias RoomSanctum.Condenser.BasicMQTT
  alias RoomSanctum.Storage
  alias RoomSanctumWeb.Components.QueryGeospatialMap

  @doc """
  ADS-B aircraft from a vision worker's data, which is keyed by
  `{query_id, source_type}`.

  Only icarus queries carry aircraft; everything else in the map is left alone.
  """
  def aircraft(preview) when is_map(preview) or is_list(preview) do
    preview
    |> Enum.flat_map(fn
      {{_query_id, :icarus}, data} -> QueryGeospatialMap.aircraft_from_preview(:icarus, data)
      _other -> []
    end)
  end

  def aircraft(_preview), do: []

  @doc """
  Free-floating bikes from a vision worker's data.

  Only an area query answers with these -- a station query answers with the
  dock, which is already on the map as the query's own marker -- so they are
  told apart by what came back rather than by reading the query back out.
  """
  def free_bikes(preview) when is_map(preview) or is_list(preview) do
    preview
    |> Enum.flat_map(fn
      {{_query_id, :gbfs}, data} when is_list(data) ->
        Enum.filter(data, &match?(%{bike_id: bike_id} when not is_nil(bike_id), &1))

      _other ->
        []
    end)
  end

  def free_bikes(_preview), do: []

  @doc """
  Docks from a vision worker's data.

  Only an area query asked to include them answers with docks it was not told
  about by id; a station query's own dock is already the query's marker, but it
  comes back through here too and draws as one -- the same dock either way, and
  the map de-duplicates on the marker id.
  """
  def stations(preview) when is_map(preview) or is_list(preview) do
    preview
    |> Enum.flat_map(fn
      {{_query_id, :gbfs}, data} when is_list(data) -> Enum.filter(data, &dock?/1)
      _other -> []
    end)
  end

  def stations(_preview), do: []

  @doc """
  As stations/1 for a single gbfs query's own preview.
  """
  def stations_for(%{source: %{type: :gbfs}}, preview) when is_list(preview),
    do: Enum.filter(preview, &dock?/1)

  def stations_for(_query, _preview), do: []

  # A dock names itself and has somewhere to be; get_current_information_for_
  # bikestop returns nil for a station id the feed has never mentioned, which
  # is neither.
  defp dock?(%{station_id: station_id} = entry) when not is_nil(station_id),
    do: Map.get(entry, :place) != nil or Map.get(entry, :lat) != nil

  defp dock?(_entry), do: false

  @doc """
  As free_bikes/1 for a single gbfs query's own preview.
  """
  def free_bikes_for(%{source: %{type: :gbfs}}, preview) when is_list(preview),
    do: Enum.filter(preview, &match?(%{bike_id: bike_id} when not is_nil(bike_id), &1))

  def free_bikes_for(_query, _preview), do: []

  @doc """
  Air-quality observations around an aqi query -- the station it answers with
  first, then its neighbours.

  For a single query those neighbours are context: whether the number is local
  or the whole city is like that. On a vision's map they are the only reason
  an aqi query is more than one dot.
  """
  def aqi_stations(%{source: %{type: :aqi}} = query) do
    case query.query do
      %{aqsid: aqsid} = q when is_binary(aqsid) and aqsid != "" ->
        case Storage.get_aqi_station(query.source_id, aqsid) do
          [station] -> Storage.nearby_aqi_stations(query.source_id, station.point, 6)
          _ -> from_foci(query, q)
        end

      %{foci_id: foci_id} when not is_nil(foci_id) ->
        Storage.nearest_aqi_stations(query.source_id, foci_id, 6)

      _ ->
        []
    end
  end

  def aqi_stations(_query), do: []

  defp from_foci(query, %{foci_id: foci_id}) when not is_nil(foci_id),
    do: Storage.nearest_aqi_stations(query.source_id, foci_id, 6)

  defp from_foci(_query, _q), do: []

  @doc """
  The map speaks stations, not observations.
  """
  def as_stations(observations) do
    Enum.map(observations, fn obs ->
      %{
        place: obs.point,
        station_id: obs.aqsid,
        name: obs.site_name || obs.aqsid,
        short_name: obs.aqsid,
        capacity: 0,
        address: obs.reporting_areas |> List.wrap() |> List.first(),
        lat: obs.lat,
        lon: obs.lon
      }
    end)
  end

  @doc """
  What each query currently says, as a few short lines for its map marker.

  The same numbers the Basic preview cards show, from the same condenser, so a
  marker and the card beside it cannot disagree -- a popup that reports only
  the coordinates is telling the reader the one thing the marker's position
  already told them.

  Keyed by query id, capped at four lines: this is a popup, not the card.
  """
  @summary_lines 4

  def summaries(preview) when is_map(preview) or is_list(preview) do
    Enum.into(preview, %{}, fn {{query_id, type}, data} ->
      {query_id, summarise(type, data)}
    end)
  end

  def summaries(_preview), do: %{}

  @doc """
  As summaries/1 for a single query's own preview, which is the bare result
  rather than the {query_id, type} map a vision keeps.
  """
  def summaries(%{id: id, source: %{type: type}}, preview),
    do: %{id => summarise(type, preview)}

  def summaries(_query, _preview), do: %{}

  defp summarise(type, data) do
    type
    |> condense(data)
    |> lines(type)
    |> Enum.reject(fn %{value: value} -> value in [nil, ""] end)
    |> Enum.take(@summary_lines)
  rescue
    # A condenser reaches deep into whatever the worker returned, and a feed
    # mid-refresh can hand it a shape it does not expect. A marker with no
    # summary is worth more than a map that does not render.
    _ -> []
  end

  defp condense(_type, data) when data in [nil, [], %{}], do: []
  defp condense(type, data), do: BasicMQTT.condense_data({nil, type}, data)

  # Route and destination, then when it is actually coming -- live times where
  # the feed has them, which is the number the card leads with too.
  defp lines(entries, :gtfs) when is_list(entries) do
    Enum.map(entries, fn e ->
      live = e |> Map.get(:times_live, []) |> List.wrap() |> Enum.reject(&is_nil/1)
      times = if live == [], do: Map.get(e, :times, []), else: live

      # The route and where it is going are the data, so they stay as words;
      # the glyph goes on the times, and says which kind of time it is -- the
      # broadcast tower for a live arrival, the clock for the timetable, as the
      # card does.
      %{
        label: "#{Map.get(e, :route_name) || e.route} to #{e.dest}",
        value_icon: if(live != [], do: "tower-broadcast", else: "clock"),
        value: times |> Enum.take(2) |> Enum.map_join(", ", &to_string/1)
      }
    end)
  end

  # An area query is a count, not a list: twenty bikes is twenty markers on the
  # map already, and naming them one by one in the popup of the foci they are
  # around says nothing.
  defp lines([%{kind: :free_bike} | _] = entries, :gbfs) do
    {bikes, docks} = Enum.split_with(entries, &(Map.get(&1, :kind) == :free_bike))
    available = Enum.reject(bikes, & &1.disabled)

    [
      %{icon: "bicycle", label: "Free bikes", value: "#{length(available)} nearby"},
      %{
        icon: "road",
        label: "Best range",
        value:
          available
          |> Enum.map(& &1.range_m)
          |> Enum.reject(&is_nil/1)
          |> case do
            [] -> nil
            ranges -> "#{Float.round(Enum.max(ranges) / 1000, 1)} km"
          end
      },
      %{
        icon: "square-parking",
        label: "Docks",
        value:
          case docks do
            [] -> nil
            docks -> "#{Enum.sum(Enum.map(docks, &(&1.avail || 0)))} bikes at #{length(docks)}"
          end
      }
    ]
  end

  defp lines(entries, :gbfs) when is_list(entries) do
    Enum.flat_map(entries, fn e ->
      [
        %{icon: "bicycle", label: "Bikes", value: "#{e.avail - e.avail_elec}"},
        %{icon: "bolt-lightning", label: "Electric bikes", value: "#{e.avail_elec}"},
        %{icon: "square-parking", label: "Docks free", value: "#{e.docks_avail} of #{e.capacity}"}
      ]
    end)
  end

  defp lines(entries, :weather) when is_list(entries) do
    Enum.flat_map(entries, fn e ->
      [
        %{label: e.name, value: e.weather},
        %{label: "Temperature", value: "#{e.temp}#{degrees(e.units)} (feels #{e.feel})"},
        %{label: "Humidity", value: e.hum && "#{e.hum}%"}
      ]
    end)
  end

  defp lines(entries, :aqi) when is_list(entries) do
    Enum.flat_map(entries, fn e ->
      [%{icon: "lungs", label: "Station", value: Map.get(e, :name)} | readings(e)]
    end)
  end

  # Everything else: the condensers all produce maps of small named values, so
  # show the first few rather than write a formatter per source type. A source
  # whose popup deserves better gets a clause above.
  defp lines(entries, _type) when is_list(entries) do
    entries
    |> Enum.flat_map(fn
      entry when is_map(entry) ->
        entry
        |> Map.drop([:__struct__, :kind, :id, :lat, :lon, :tz, :units])
        |> Enum.filter(fn {_k, v} -> scalar?(v) end)
        |> Enum.map(fn {k, v} -> %{label: humanise(k), value: to_string(v)} end)

      _other ->
        []
    end)
  end

  defp lines(entries, type) when is_map(entries), do: lines([entries], type)
  defp lines(_entries, _type), do: []

  # As the cards label them, rather than as the field is spelled: "PM25" is not
  # what anyone calls it.
  @pollutants [pm25: "PM2.5", pm10: "PM10", no2: "NO2", ozone: "O3", so2: "SO2", co: "CO"]

  defp readings(entry) do
    Enum.flat_map(@pollutants, fn {key, label} ->
      case Map.get(entry, key) do
        nil -> []
        value -> [%{label: label, value: to_string(value)}]
      end
    end)
  end

  defp degrees(:imperial), do: "F"
  defp degrees("imperial"), do: "F"
  defp degrees(_), do: "C"

  defp scalar?(v) when is_binary(v) or is_number(v) or is_boolean(v) or is_atom(v), do: not is_nil(v)
  defp scalar?(_), do: false

  defp humanise(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @doc """
  Live vehicle positions for a gtfs query, narrowed to the trips or routes that
  query is about and given the route and destination the schedule knows.

  Wrapped, because a feed that is mid-refresh or a worker that is not up yet
  should cost the map its vehicles, not the whole page.
  """
  def vehicle_positions(%{source: %{type: :gtfs}} = query) do
    try do
      case RoomGtfs.Worker.get_current_vehicle_positions(query.source.id) do
        vehicles when is_list(vehicles) ->
          vehicles
          |> filter_for_query(query)
          |> Storage.with_trip_context(query.source_id)

        _ ->
          []
      end
    rescue
      _ -> []
    catch
      _, _ -> []
    end
  end

  def vehicle_positions(_query), do: []

  @doc """
  Narrow a feed's vehicles to one query: the trips calling at its stop, or the
  routes it names.
  """
  def filter_for_query(vehicles, %{query: %{stop: stop_id}} = query)
      when not is_nil(stop_id) do
    trip_ids =
      query.source.id
      |> Storage.get_trips_for_stop(to_string(stop_id))
      |> Enum.map(& &1.trip_id)
      |> MapSet.new()

    Enum.filter(vehicles, fn v -> v.trip_id && MapSet.member?(trip_ids, v.trip_id) end)
  rescue
    _ -> []
  end

  def filter_for_query(vehicles, %{query: %{routes: route_ids}}) when is_list(route_ids) do
    Enum.filter(vehicles, fn v -> v.route_id && v.route_id in route_ids end)
  end

  def filter_for_query(_vehicles, _query), do: []
end
