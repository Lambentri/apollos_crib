defmodule RoomSanctumWeb.Components.QueryGeospatialMap do
  use Phoenix.Component
  import RoomSanctumWeb.CoreComponents

  @doc """
  Renders an interactive Leaflet map showing queries based on their geospatial point data.
  
  ## Examples
  
      <.query_geospatial_map queries={@queries} />
      
      <.query_geospatial_map queries={@queries} selected_tint={@tint} />
  """
  attr :queries, :list, required: true
  attr :selected_tint, :string, default: nil
  attr :class, :string, default: ""
  attr :height, :string, default: "500px"

  def query_geospatial_map(assigns) do
    assigns = assign(assigns, :map_queries, get_mappable_queries(assigns.queries))
    
    ~H"""
    <div class={"query-geospatial-map w-full #{@class}"}>
      <!-- Map container -->
      <div 
        id="leaflet-map" 
        class="w-full border border-gray-300 rounded-lg shadow-sm overflow-hidden"
        style={"height: #{@height}; width: 100%; max-width: 100%; position: relative; box-sizing: border-box;"}
        phx-hook="LeafletMap"
        data-queries={Jason.encode!(@map_queries)}
        data-selected-tint={@selected_tint}
      >
        <!-- Loading state -->
        <div class="flex items-center justify-center h-full bg-gray-50">
          <div class="text-center">
            <i class="fa-solid fa-map text-4xl text-gray-400 mb-2"></i>
            <p class="text-gray-500">Loading map...</p>
          </div>
        </div>
      </div>
      
      <!-- Map legend/info -->
      <div class="mt-4 bg-white border border-gray-200 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-gray-700">
            Map Legend
            <span class="ml-2 text-xs text-gray-500">
              (<%= length(@map_queries) %> queries with location data)
            </span>
          </h3>
          
          <%= if @selected_tint do %>
            <span class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-#{@selected_tint}-100 text-#{@selected_tint}-800"}>
              <i class={"fa-solid fa-circle text-#{@selected_tint}-500 mr-1"}></i>
              Filtered: <%= @selected_tint %>
            </span>
          <% end %>
        </div>
        
        <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-2 text-xs">
          <%= for type <- get_unique_types(@map_queries) do %>
            <div class="flex items-center">
              <i class={"fas fa-fw #{get_icon(type)} mr-1 text-gray-600"}></i>
              <span class="capitalize text-gray-700"><%= type %></span>
            </div>
          <% end %>
        </div>
        
        <%= if length(@map_queries) == 0 do %>
          <div class="text-center py-4 text-gray-500">
            <i class="fa-solid fa-map-location-dot text-2xl mb-2"></i>
            <p>No queries with location data found</p>
            <%= if @selected_tint do %>
              <p class="text-sm">Try removing the tint filter or adding location data to your sources</p>
            <% else %>
              <p class="text-sm">Add geospatial data to your sources to see them on the map</p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper function to get queries that have geospatial data
  defp get_mappable_queries(queries) do
    # Debug log all incoming queries
    IO.inspect(length(queries), label: "Total queries received")
    
    filtered = queries
    |> Enum.filter(fn query ->
      # Check if query has geom field, source has point data, or internal query data has coordinates
      has_geom = query.geom != nil
      has_source_point = query.source && has_point_data?(query.source)
      has_query_point = extract_from_query_data(query) != false
      
      result = has_geom || has_source_point || has_query_point
      IO.inspect({query.id, query.name, has_geom, has_source_point, has_query_point, result}, label: "Query mappability check")
      result
    end)
    
    IO.inspect(length(filtered), label: "Filtered mappable queries")
    
    mapped = filtered |> Enum.map(&format_query_for_map/1)
    
    IO.inspect(length(mapped), label: "Final mapped queries")
    
    mapped
  end

  # Check if source has point data - adapt this to your source schema
  defp has_point_data?(source) do
    # Check if source struct has geom field and it's not nil
    # For structs, we need to pattern match or use Map.get with a default
    geom = Map.get(source, :geom, nil)
    lat = Map.get(source, :lat, nil)
    lng = Map.get(source, :lng, nil)
    latitude = Map.get(source, :latitude, nil)
    longitude = Map.get(source, :longitude, nil)
    coordinates = Map.get(source, :coordinates, nil)
    
    geom != nil || 
    (lat != nil && lng != nil) ||
    (latitude != nil && longitude != nil) ||
    coordinates != nil
  end

  # Format query data for the JavaScript map component
  defp format_query_for_map(query) do
    {lat, lng} = extract_coordinates(query)
    
    # Debug log the coordinate extraction
    IO.inspect({query.id, query.name, lat, lng}, label: "Map coordinates for query")
    
    tint = cond do
      query.meta && query.meta.tint -> query.meta.tint
      query.source && query.source.meta && query.source.meta.tint -> query.source.meta.tint
      true -> nil
    end

    %{
      id: query.id,
      name: query.name,
      source_name: query.source.name,
      source_type: query.source.type,
      lat: lat,
      lng: lng,
      tint: tint,
      icon: get_icon(query.source.type),
      notes: query.notes
    }
  end

  # Extract lat/lng coordinates from query or source
  defp extract_coordinates(query) do
    cond do
      query.geom != nil ->
        # Handle PostGIS geometry - you may need to adjust this based on your Geo setup
        case query.geom do
          %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
          _ -> {0, 0} # fallback
        end
        
      query.source && has_point_data?(query.source) ->
        source = query.source
        geom = Map.get(source, :geom, nil)
        lat = Map.get(source, :lat, nil)
        lng = Map.get(source, :lng, nil)
        latitude = Map.get(source, :latitude, nil)
        longitude = Map.get(source, :longitude, nil)
        
        cond do
          geom != nil ->
            case geom do
              %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
              _ -> {0, 0}
            end
          lat != nil && lng != nil ->
            {lat, lng}
          latitude != nil && longitude != nil ->
            {latitude, longitude}
          true -> {0, 0}
        end

      # Handle data from the query's underlying stop/thing being queried
      query.query && extract_from_query_data(query) ->
        extract_from_query_data(query)
        
      true -> {0, 0}
    end
  end

  # Extract coordinates from the internal query data (stops, stations, etc.)
  defp extract_from_query_data(query) do
    case query.source.type do
      :gtfs ->
        # For GTFS, get coordinates from the stop being queried
        if query.query && Map.has_key?(query.query, :stop) do
          get_gtfs_stop_coordinates(query.source.id, query.query.stop)
        else
          false
        end

      :gbfs ->
        # For GBFS, get coordinates from the station being queried  
        if query.query && Map.has_key?(query.query, :stop_id) do
          get_gbfs_station_coordinates(query.source.id, query.query.stop_id)
        else
          false
        end

      :aqi ->
        # For AQI, get coordinates from the monitoring site/foci
        if query.query && Map.has_key?(query.query, :foci_id) do
          get_aqi_foci_coordinates(query.query.foci_id)
        else
          false
        end

      _ -> 
        false
    end
  end

  # Get coordinates for GTFS stop
  defp get_gtfs_stop_coordinates(source_id, stop_id) do
    case RoomSanctum.Storage.get_stop_by_id(source_id, stop_id) do
      nil -> false
      stop when stop.stop_lat != nil and stop.stop_lon != nil ->
        {stop.stop_lat, stop.stop_lon}
      _ -> false
    end
  end

  # Get coordinates for GBFS station
  defp get_gbfs_station_coordinates(source_id, station_id) do
    case RoomSanctum.Storage.get_gbfs_station_by_id(source_id, station_id) do
      nil -> false
      station ->
        cond do
          # First try the PostGIS geometry field if it exists
          station.place != nil ->
            case station.place do
              %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
              _ -> false
            end
          # Fall back to separate lat/lon fields
          station.lat != nil && station.lon != nil ->
            {station.lat, station.lon}
          true -> false
        end
    end
  end

  # Get coordinates for AQI foci
  defp get_aqi_foci_coordinates(foci_id) do
    case RoomSanctum.Storage.get_foci_by_id(foci_id) do
      nil -> false
      foci when foci.point != nil ->
        case foci.point do
          %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
          _ -> false
        end
      _ -> false
    end
  end

  # Get unique source types for the legend
  defp get_unique_types(queries) do
    queries
    |> Enum.map(& &1.source_type)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Icon helper (delegate to existing IconHelpers)
  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end
end
