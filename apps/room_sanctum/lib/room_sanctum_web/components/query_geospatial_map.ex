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
  attr :vehicle_positions, :list, default: []
  attr :free_bikes, :list, default: []
  attr :stations, :list, default: []
  attr :station_statuses, :list, default: []
  attr :source_tint, :string, default: nil

  def query_geospatial_map(assigns) do
    assigns = 
      assigns 
      |> assign(:map_queries, get_mappable_queries(assigns.queries))
      |> assign(:map_vehicles, format_vehicle_positions(assigns.vehicle_positions))
      |> assign(:map_free_bikes, format_free_bikes(assigns.free_bikes))
      |> assign(:map_stations, format_stations(assigns.stations, Map.get(assigns, :station_statuses, []), Map.get(assigns, :source_tint, nil)))
    
    ~H"""
    <div class={"query-geospatial-map w-full #{@class}"}>
      <!-- Map container -->
      <div 
        id="leaflet-map" 
        class="w-full border border-gray-300 rounded-lg shadow-sm overflow-hidden"
        style={"height: #{@height}; width: 100%; max-width: 100%; position: relative; box-sizing: border-box;"}
        phx-hook="LeafletMap"
        data-queries={Jason.encode!(@map_queries)}
        data-vehicles={Jason.encode!(@map_vehicles)}
        data-free-bikes={Jason.encode!(@map_free_bikes)}
        data-stations={Jason.encode!(@map_stations)}
        data-selected-tint={@selected_tint}
      >
        <!-- Loading state -->
        <div class="flex items-center justify-center h-full bg-base-200">
          <div class="text-center">
            <i class="fa-solid fa-map text-4xl text-base-content/60 mb-2"></i>
            <p class="text-base-content/70">Loading map...</p>
          </div>
        </div>
      </div>
      
      <!-- Map legend/info -->
      <div class="mt-4 bg-base-100 border border-base-300 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-base-content">
            Map Legend
            <span class="ml-2 text-xs text-base-content/60">
              (<%= length(@map_queries) %> queries with location data<%= if length(@map_free_bikes) > 0, do: ", #{length(@map_free_bikes)} free bikes", else: "" %>)
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
              <i class={"fas fa-fw #{get_icon(type)} mr-1 text-base-content/70"}></i>
              <span class="capitalize text-base-content/80"><%= type %></span>
            </div>
          <% end %>
          
          <%= if length(@map_free_bikes) > 0 do %>
            <div class="flex items-center">
              <i class="fas fa-fw fa-bicycle mr-1 text-green-600"></i>
              <span class="capitalize text-base-content/80">Free Bikes</span>
            </div>
          <% end %>
        </div>
        
        <%= if length(@map_queries) == 0 and length(@map_free_bikes) == 0 do %>
          <div class="text-center py-4 text-base-content/60">
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
#      IO.inspect({query.id, query.name, has_geom, has_source_point, has_query_point, result}, label: "Query mappability check")
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
#    IO.inspect({query.id, query.name, lat, lng}, label: "Map coordinates for query")
    
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
        # For GTFS, get coordinates from the stop being queried or vehicle positions
        cond do
          query.query && Map.has_key?(query.query, :stop) ->
            get_gtfs_stop_coordinates(query.source.id, query.query.stop)
          
          # Check if this is a vehicle position query
          query.source.config && Map.get(query.source.config, :url_rt_vp) ->
            get_gtfs_vehicle_coordinates(query.source.id, query)
          
          true ->
            false
        end

      :gbfs ->
        # For GBFS, get coordinates from the station or area-based free bike query  
        cond do
          query.query && Map.has_key?(query.query, :stop_id) ->
            get_gbfs_station_coordinates(query.source.id, query.query.stop_id)
          query.query && (Map.has_key?(query.query, :radius) || Map.has_key?(query.query, :point)) ->
            get_gbfs_free_bikes_in_area_coordinates(query.source.id, query.query)
          true ->
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

  # Get coordinates for GBFS free bikes in area
  defp get_gbfs_free_bikes_in_area_coordinates(source_id, query_params) do
    # Extract point and radius from query parameters
    {point, radius} = case query_params do
      %{point: %Geo.Point{} = geo_point, radius: radius} ->
        {geo_point, radius}
      %{lat: lat, lng: lng, radius: radius} when is_number(lat) and is_number(lng) ->
        {%Geo.Point{coordinates: {lng, lat}}, radius}
      %{latitude: lat, longitude: lng, radius: radius} when is_number(lat) and is_number(lng) ->
        {%Geo.Point{coordinates: {lng, lat}}, radius}
      _ ->
        {nil, nil}
    end
    
    case {point, radius} do
      {%Geo.Point{} = geo_point, radius} when is_number(radius) ->
        # Find bikes in the area using existing Storage function
        case RoomSanctum.Storage.find_free_bikes_around_point(source_id, geo_point, radius) do
          [] -> 
            false
          bikes when is_list(bikes) ->
            # Return the center point of the query area
            %Geo.Point{coordinates: {lng, lat}} = geo_point
            {lat, lng}
        end
      _ ->
        false
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

  # Get coordinates from GTFS vehicle positions
  defp get_gtfs_vehicle_coordinates(source_id, query) do
    try do
      case RoomGtfs.Worker.get_current_vehicle_positions(source_id) do
        [] -> 
          false
        
        vehicles when is_list(vehicles) ->
          # Return the first vehicle position found, or average if multiple
          case List.first(vehicles) do
            %{latitude: lat, longitude: lng} when lat != nil and lng != nil ->
              {lat, lng}
            _ -> 
              false
          end
        
        _ -> 
          false
      end
    rescue
      _ -> 
        false
    catch
      _ -> 
        false
    end
  end

  # Format vehicle positions for map display
  defp format_vehicle_positions(vehicle_positions) do
    vehicle_positions
    |> Enum.filter(fn vehicle -> 
      vehicle.latitude != nil && vehicle.longitude != nil 
    end)
    |> Enum.map(fn vehicle ->
      %{
        id: "vehicle_#{vehicle.vehicle_id}",
        type: "vehicle",
        vehicle_id: vehicle.vehicle_id,
        trip_id: vehicle.trip_id,
        route_id: vehicle.route_id,
        lat: vehicle.latitude,
        lng: vehicle.longitude,
        bearing: vehicle.bearing,
        timestamp: vehicle.timestamp,
        icon: "fa-bus" # or different icon based on vehicle type
      }
    end)
  end

  # Format free bikes for map display
  defp format_free_bikes(free_bikes) do
    free_bikes
    |> Enum.filter(fn bike -> 
      (bike.point != nil) || (bike.lat != nil && bike.lon != nil)
    end)
    |> Enum.map(fn bike ->
      {lat, lng} = cond do
        bike.point != nil ->
          case bike.point do
            %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
            _ -> {0, 0}
          end
        bike.lat != nil && bike.lon != nil ->
          {bike.lat, bike.lon}
        true -> {0, 0}
      end

      # Extract additional fields with defaults
      is_disabled = Map.get(bike, :is_disabled, false)
      is_reserved = Map.get(bike, :is_reserved, false)
      current_range_meters = Map.get(bike, :current_range_meters, nil)
      vehicle_type_id = Map.get(bike, :vehicle_type_id, nil)

      # Calculate battery info if range is available
      {battery_level, battery_icon, battery_color} = get_battery_info(current_range_meters)

      %{
        id: "bike_#{bike.bike_id}",
        type: "free_bike",
        bike_id: bike.bike_id,
        lat: lat,
        lng: lng,
        is_disabled: is_disabled,
        is_reserved: is_reserved,
        vehicle_type_id: vehicle_type_id,
        current_range_meters: current_range_meters,
        battery_level: battery_level,
        battery_icon: battery_icon,
        battery_color: battery_color,
        icon: "fa-bicycle" # bike icon
      }
    end)
  end

  @doc """
  Calculate battery information from current_range_meters.
  
  Divides range by 45000 to get approximate battery level percentage,
  then returns appropriate FontAwesome battery icon and color.
  
  Returns {battery_level_percent, icon_class, color}
  """
  def get_battery_info(current_range_meters) when is_number(current_range_meters) do
    battery_level = (current_range_meters / 45000.0 * 100) |> Float.round(1)
    
    {icon, color} = cond do
      battery_level < 10 -> {"fa-battery-empty", "black"}
      battery_level < 30 -> {"fa-battery-quarter", "red"}
      battery_level < 50 -> {"fa-battery-half", "orange"}
      battery_level < 80 -> {"fa-battery-three-quarters", "yellow"}
      true -> {"fa-battery-full", "green"}
    end
    
    {battery_level, icon, color}
  end
  
  def get_battery_info(_), do: {nil, nil, nil}
  
  @doc """
  Get battery icon class for a given battery level percentage.
  
  ## Examples
  
      iex> get_battery_icon(5.0)
      "fa-battery-empty"
      
      iex> get_battery_icon(25.0)
      "fa-battery-quarter"
      
      iex> get_battery_icon(45.0)  
      "fa-battery-half"
      
      iex> get_battery_icon(75.0)
      "fa-battery-three-quarters"
      
      iex> get_battery_icon(95.0)
      "fa-battery-full"
  """
  def get_battery_icon(battery_level) when is_number(battery_level) do
    cond do
      battery_level < 10 -> "fa-battery-empty"
      battery_level < 30 -> "fa-battery-quarter"
      battery_level < 50 -> "fa-battery-half"
      battery_level < 80 -> "fa-battery-three-quarters"
      true -> "fa-battery-full"
    end
  end
  
  def get_battery_icon(_), do: nil
  
  @doc """
  Get battery color for a given battery level percentage.
  
  ## Examples
  
      iex> get_battery_color(5.0)
      "black"
      
      iex> get_battery_color(25.0)
      "red"
      
      iex> get_battery_color(45.0)
      "orange"
      
      iex> get_battery_color(75.0)
      "yellow"
      
      iex> get_battery_color(95.0)
      "green"
  """
  def get_battery_color(battery_level) when is_number(battery_level) do
    cond do
      battery_level < 10 -> "black"
      battery_level < 30 -> "red"
      battery_level < 50 -> "orange"
      battery_level < 80 -> "yellow"
      true -> "green"
    end
  end
  
  def get_battery_color(_), do: nil
  
  # Format stations for map display
  defp format_stations(stations, station_statuses \\ [], source_tint \\ nil) do
    # Create a map of station status by station_id for quick lookup
    status_map = Enum.reduce(station_statuses, %{}, fn status, acc ->
      Map.put(acc, status.station_id, status)
    end)

    stations
    |> Enum.filter(fn station -> 
      (station.place != nil) || (station.lat != nil && station.lon != nil)
    end)
    |> Enum.map(fn station ->
      {lat, lng} = cond do
        station.place != nil ->
          case station.place do
            %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
            _ -> {0, 0}
          end
        station.lat != nil && station.lon != nil ->
          {station.lat, station.lon}
        true -> {0, 0}
      end

      # Get associated station status
      status = Map.get(status_map, station.station_id, nil)

      station_data = %{
        id: "station_#{station.station_id}",
        type: "station",
        station_id: station.station_id,
        name: Map.get(station, :name, "Unknown Station"),
        short_name: Map.get(station, :short_name, ""),
        capacity: Map.get(station, :capacity, 0),
        address: Map.get(station, :address, ""),
        lat: lat,
        lng: lng,
        tint: source_tint,  # Use the source tint passed from the parent
        icon: "fa-bicycle"
      }

      # Add station status fields if available
      if status do
        station_data
        |> Map.put(:num_bikes_available, status.num_bikes_available)
        |> Map.put(:num_ebikes_available, status.num_ebikes_available)
        |> Map.put(:num_docks_available, status.num_docks_available)
        |> Map.put(:is_installed, status.is_installed)
        |> Map.put(:is_renting, status.is_renting)
        |> Map.put(:is_returning, status.is_returning)
        |> Map.put(:station_status, status.station_status)
        |> Map.put(:last_reported, status.last_reported)
      else
        station_data
      end
    end)
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
