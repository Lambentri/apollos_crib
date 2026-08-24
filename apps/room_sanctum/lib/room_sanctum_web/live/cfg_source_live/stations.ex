defmodule RoomSanctumWeb.SourceLive.Stations do
  @moduledoc """
  One shape for the places a source knows about.

  GTFS stops carry `stop_lat`/`stop_lon`/`stop_name`, GBFS stations use
  `lat`/`lon`/`name`, and an AirNow record is both a reading and the site that
  made it. The map component is taught one vocabulary rather than three.

  This lives apart from the LiveViews because two of them need it: an
  offering's own map draws one source, and the tint map draws every source
  sharing a colour. Held privately in either, the normalisation would be
  copied, and a copy of "what counts as a place" is the kind of thing that
  drifts silently -- one map gaining a field or a filter the other does not.

  ## What has no places

  Only `:gtfs`, `:gbfs` and `:aqi` store geography of their own. A weather,
  tidal or ephem source has no coordinates anywhere in its config; where you
  want the weather is a property of the *query*, not of the source. So
  `for_source/1` returns `[]` for them, and that is an answer rather than a
  gap -- see `mappable?/1` for asking before drawing.
  """

  alias RoomSanctum.Storage

  @mappable [:gtfs, :gbfs, :aqi]

  @doc "Whether a source has geography of its own to draw."
  def mappable?(%{type: type}), do: type in @mappable
  def mappable?(_), do: false

  @doc "The source types that can appear on a map at all."
  def mappable_types, do: @mappable

  @doc """
  Every place a source knows about, normalised.

  Returns `[]` for a source type that stores no geography.
  """
  def for_source(%{type: :gbfs, id: id}), do: Storage.list_gbfs_station_information(id)

  def for_source(%{type: :gtfs, id: id}),
    do: id |> Storage.list_stops() |> Enum.map(&stop_as_station/1)

  def for_source(%{type: :aqi, id: id}),
    do: id |> Storage.list_aqi_stations() |> Enum.map(&site_as_station/1)

  def for_source(_source), do: []

  @doc """
  Live dock counts, which only GBFS has.

  Kept separate because the map component takes statuses as their own list and
  joins them to stations on `station_id`.
  """
  def statuses_for_source(%{type: :gbfs, id: id}), do: Storage.list_gbfs_station_status(id)
  def statuses_for_source(_source), do: []

  @doc """
  Names the source in each station's label.

  Only wanted where one map holds several sources: on an offering's own map
  every marker belongs to the source you are already looking at, and repeating
  its name on all four thousand of them is noise. On the tint map it is the
  only way to tell whose stop you clicked, since the marker element carries no
  source of its own.
  """
  def label_with_source(stations, source) do
    Enum.map(stations, fn station ->
      name = Map.get(station, :name)

      labelled =
        case name do
          nil -> source.name
          "" -> source.name
          n -> "#{n} · #{source.name}"
        end

      # Map.put over both shapes: GBFS stations arrive as Ecto structs and the
      # other two as plain maps, and every one of them has a :name.
      Map.put(station, :name, labelled)
    end)
  end

  # Every key here has to be present even when it is nil: the map component's
  # format_stations/3 reaches for :place directly, so a map without it raises
  # rather than falling through to the lat/lon branch.
  defp stop_as_station(stop) do
    %{
      place: nil,
      station_id: stop.stop_id,
      name: stop.stop_name,
      short_name: stop.stop_code,
      capacity: 0,
      address: stop.stop_address,
      lat: stop.stop_lat,
      lon: stop.stop_lon
    }
  end

  # AirNow replaces its observations every hour, so a reading and the station
  # that made it are one record. The name carries the current index, since that
  # is what you want off a marker without opening it.
  defp site_as_station(observation) do
    %{
      place: observation.point,
      station_id: observation.aqsid,
      name: station_label(observation),
      short_name: observation.aqsid,
      capacity: 0,
      address: observation.reporting_areas |> List.wrap() |> List.first(),
      lat: observation.lat,
      lon: observation.lon
    }
  end

  defp station_label(observation) do
    name = observation.site_name || observation.aqsid

    case RoomSanctum.Storage.AirNow.HourlyObsData.overall_aqi(observation) do
      nil -> name
      {value, pollutant} -> "#{name} - AQI #{value} (#{pollutant})"
    end
  end
end
