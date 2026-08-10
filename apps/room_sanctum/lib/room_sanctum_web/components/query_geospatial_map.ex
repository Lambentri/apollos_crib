defmodule RoomSanctumWeb.Components.QueryGeospatialMap do
  use Phoenix.Component
  import RoomSanctumWeb.CoreComponents
  alias RoomSanctum.Configuration

  @doc """
  Renders an interactive Leaflet map showing queries based on their geospatial point data.
  
  ## Examples
  
      <.query_geospatial_map queries={@queries} />
      
      <.query_geospatial_map queries={@queries} selected_tint={@tint} />
  """
  attr :id, :string,
    default: "geospatial-map",
    doc: """
    DOM id for the map and the prefix for its marker ids. Needs to differ when
    two maps can be on screen together -- the tester map and the offering's
    map view can both be open, and duplicate ids let LiveView's patching move
    markers between them.
    """

  attr :queries, :list, required: true
  attr :selected_tint, :string, default: nil
  attr :class, :string, default: ""
  attr :height, :string, default: "500px"

  attr :max_markers, :integer,
    default: nil,
    doc: "Optional cap on rendered markers. Nil shows everything, which is the default."

  attr :queried_station_ids, :list,
    default: [],
    doc: "Station ids that already have a query; those markers render as queries and lose the add action."

  attr :add_query_event, :string,
    default: nil,
    doc: "When set, station markers get a '+ query' action in their popup that pushes this event."

  attr :vehicle_positions, :list, default: []
  attr :free_bikes, :list, default: []
  attr :aircraft, :list, default: [],
    doc: "ADS-B aircraft as room_icarus normalises them: string keys, lat/lon/track/class."

  attr :stations, :list, default: []
  attr :station_statuses, :list, default: []
  attr :source_tint, :string, default: nil

  attr :focus, :map,
    default: nil,
    doc: """
    %{lat:, lng:} to centre on, instead of the centroid of the markers. Needed
    to look at one place: the computed view fits everything on screen and
    bottoms out at zoom 13, which is too far back to read a single stop.
    """

  attr :focus_zoom, :integer,
    default: 15,
    doc: "Zoom used with :focus. Only consulted when :focus is set."

  attr :route_types, :map,
    default: %{},
    doc: """
    route_id => GTFS route_type, used to pick the glyph a vehicle is drawn
    with. Vehicle positions only carry a route_id, and the type lives on the
    route, so the caller resolves it once rather than per marker.
    """

  attr :route_lines, :list,
    default: [],
    doc: """
    Muted polylines under the markers: [%{id:, points: [[lat, lng], ...],
    color:}]. Empty by default -- on a full feed this is hundreds of lines.
    """

  attr :route_lines_event, :string,
    default: nil,
    doc: """
    When set, the map carries its own route-lines toggle pushing this event.
    Left nil the control is not rendered, which is what a map whose owner
    cannot supply route geometry should do.
    """

  attr :show_route_lines, :boolean,
    default: false,
    doc: "Whether the toggle reads as on. The state lives with the caller."

  attr :legend, :boolean,
    default: true,
    doc: """
    The legend counts marker types and explains itself when there is nothing to
    show. Turn it off where the map is deliberately narrow -- a single place --
    and its "no queries found" empty state would only be noise.
    """

  def query_geospatial_map(assigns) do
    assigns = 
      assigns 
      |> assign(:map_queries, get_mappable_queries(assigns.queries))
      |> assign(:map_vehicles, format_vehicle_positions(assigns.vehicle_positions, assigns.route_types))
      |> assign(:map_free_bikes, format_free_bikes(assigns.free_bikes))
      |> assign(:map_aircraft, format_aircraft(assigns.aircraft))
      |> assign(:map_stations, format_stations(assigns.stations, Map.get(assigns, :station_statuses, []), Map.get(assigns, :source_tint, nil)))
    groups = [
      assigns.map_queries,
      assigns.map_vehicles,
      assigns.map_aircraft,
      assigns.map_free_bikes,
      assigns.map_stations
    ]
    all_points = Enum.concat(groups)
    # Centre on everything, even any points a cap would drop -- unless the
    # caller named a place to look at.
    {centre_lat, centre_lng, zoom} =
      case assigns.focus do
        %{lat: lat, lng: lng} when is_number(lat) and is_number(lng) ->
          {lat, lng, assigns.focus_zoom}

        _ ->
          view_for(all_points)
      end

    # Every marker type is a canvas circleMarker sharing one renderer, so the
    # whole system draws without trouble; the cap is opt-in rather than default.
    queried = MapSet.new(Map.get(assigns, :queried_station_ids) || [], &to_string/1)
    limit = Map.get(assigns, :max_markers)
    shown_points = if is_nil(limit), do: all_points, else: balanced_take(groups, limit)

    assigns =
      assigns
      |> assign(:all_points, shown_points)
      |> assign(:queried, queried)
      # Counts as assigns: inside ~H, @foo means assigns.foo, so a module
      # attribute referenced in the template reads as nil.
      |> assign(:shown, length(shown_points))
      |> assign(:total, length(all_points))
      |> assign(:centre_lat, centre_lat)
      |> assign(:centre_lng, centre_lng)
      |> assign(:zoom, zoom)
      |> assign(:truncated, length(all_points) - length(shown_points))

  ~H"""
    <div class={"query-geospatial-map w-full #{@class}"}>
      <%!-- No phx-update here on purpose: the element patches lat/lng/zoom through
            attributeChangedCallback and markers through a MutationObserver, so
            LiveView should morph it in place rather than replace it. --%>
      <div class="mt-4 relative" id={"#{@id}-wrap"}>
        <%!-- Above Leaflet's own controls, which top out at z-index 1000
              inside the map's shadow root. --%>
        <div :if={@route_lines_event} class="absolute top-2 right-2 z-[1100]">
          <button
            type="button"
            class={"btn btn-xs gap-1 shadow #{if @show_route_lines, do: "btn-primary", else: "btn-neutral"}"}
            phx-click={@route_lines_event}
            title={if @show_route_lines, do: "Hide route lines", else: "Show route lines"}
          >
            <i class="fa-solid fa-route"></i>
            Routes
          </button>
        </div>

        <leaflet-map
          id={@id}
          class="w-full block rounded-lg overflow-hidden"
          style={"height: #{@height}"}
          lat={@centre_lat}
          lng={@centre_lng}
          zoom={@zoom}
        >
          <leaflet-line
            :for={line <- @route_lines}
            id={"#{@id}-line-#{line.id}"}
            points={Jason.encode!(line.points)}
            color={Map.get(line, :color) || "#94a3b8"}
            weight="2"
            opacity="0.3"
          ></leaflet-line>

          <%= for p <- @all_points do %>
            <%!-- Prefixed: LiveView rejects a numeric DOM id, and queries carry a
                  bare integer id while the other formatters emit strings. --%>
            <leaflet-marker
              lat={p.lat}
              lng={p.lng}
              name={Map.get(p, :name)}
              type={Map.get(p, :type)}
              tint={Map.get(p, :tint)}
              bearing={Map.get(p, :bearing)}
              route-type={Map.get(p, :route_type)}
              aircraft-class={Map.get(p, :aircraft_class)}
              id={"#{@id}-marker-#{p.id}"}
              data-has-query={
                if Map.get(p, :type) == "station" &&
                     MapSet.member?(@queried, to_string(Map.get(p, :station_id))),
                   do: "1"
              }
              data-add-query={
                if @add_query_event && Map.get(p, :type) == "station" &&
                     !MapSet.member?(@queried, to_string(Map.get(p, :station_id))),
                   do: "1"
              }
            >
              <%!-- The map forwards every marker click to the marker element, so
                    a phx-click there fired on any click. This hidden child is
                    activated only by the popup's "+ query" button. --%>
              <span
                :if={
                  @add_query_event && Map.get(p, :type) == "station" &&
                    !MapSet.member?(@queried, to_string(Map.get(p, :station_id)))
                }
                data-add-query-target
                hidden
                phx-click={@add_query_event}
                phx-value-station-id={Map.get(p, :station_id)}
                phx-value-name={Map.get(p, :name)}
              ></span>
            </leaflet-marker>
          <% end %>
        </leaflet-map>
        <%= if @truncated > 0 do %>
          <p class="text-xs text-base-content/60 mt-1">
            Showing <%= @shown %> of <%= @total %> points.
          </p>
        <% end %>
      </div>
      <div :if={@legend} class="mt-4 bg-base-100 border border-base-300 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-base-content">
            Map Legend
            <span class="ml-2 text-xs text-base-content/60">
              (<%= length(@map_queries) %> queries with location data<%= if length(@map_stations) > 0, do: ", #{length(@map_stations)} stations", else: "" %><%= if length(@map_free_bikes) > 0, do: ", #{length(@map_free_bikes)} free bikes", else: "" %><%= if length(@map_aircraft) > 0, do: ", #{length(@map_aircraft)} aircraft", else: "" %>)
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

          <%= if length(@map_aircraft) > 0 do %>
            <div class="flex items-center">
              <i class="fas fa-fw fa-plane mr-1 text-sky-400"></i>
              <span class="capitalize text-base-content/80">Aircraft</span>
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

  @doc false
  # Straight concatenation plus Enum.take drops whole categories: with 570 free
  # bikes ahead of 635 stations, a 400 cap kept zero stations. Round-robin so
  # every kind is represented, and a short list (queries) is never crowded out.
  def balanced_take(groups, limit) do
    groups
    |> Enum.reject(&(&1 == []))
    |> interleave()
    |> Enum.take(limit)
  end

  defp interleave([]), do: []

  defp interleave(lists) do
    {heads, rests} =
      Enum.reduce(lists, {[], []}, fn
        [h | t], {hs, rs} -> {[h | hs], if(t == [], do: rs, else: [t | rs])}
        [], acc -> acc
      end)

    Enum.reverse(heads) ++ interleave(Enum.reverse(rests))
  end

  # Mean of the points, with the zoom backed off as their spread grows. Falls
  # back to a continental view when there is nothing to show yet.
  defp view_for([]), do: {39.8283, -98.5795, 4}

  defp view_for(points) do
    lats = points |> Enum.map(& &1.lat) |> Enum.filter(&is_number/1)
    lngs = points |> Enum.map(& &1.lng) |> Enum.filter(&is_number/1)

    if lats == [] or lngs == [] do
      {39.8283, -98.5795, 4}
    else
      n = length(lats)
      spread = max(Enum.max(lats) - Enum.min(lats), Enum.max(lngs) - Enum.min(lngs))

      zoom =
        cond do
          spread > 5.0 -> 6
          spread > 1.0 -> 9
          spread > 0.5 -> 10
          spread > 0.25 -> 11
          spread > 0.1 -> 12
          true -> 13
        end

      {Enum.sum(lats) / n, Enum.sum(lngs) / n, zoom}
    end
  end

  # Helper function to get queries that have geospatial data
  defp get_mappable_queries(queries) do
    # Debug log all incoming queries
#    IO.inspect(length(queries), label: "Total queries received")
    
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
    
#    IO.inspect(length(filtered), label: "Filtered mappable queries")
    
    mapped = filtered |> Enum.map(&format_query_for_map/1)
    
#    IO.inspect(length(mapped), label: "Final mapped queries")
    
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
      # Explicit, so the marker carries a type attribute. Without it the colour
      # lookup fell through to the neutral grey rather than the query colour.
      type: "query",
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
  defp format_vehicle_positions(vehicle_positions, route_types \\ %{}) do
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
        route_type: Map.get(route_types, vehicle.route_id),
        timestamp: vehicle.timestamp,
        icon: "fa-bus" # or different icon based on vehicle type
      }
    end)
  end

  # ADS-B aircraft. Positions are string-keyed because that is how they leave
  # the adsb.fi payload, and the callsign is the useful label -- registration
  # or the ICAO address only when the flight is not transmitting one.
  defp format_aircraft(aircraft) do
    aircraft
    |> Enum.filter(fn ac -> ac["lat"] != nil and ac["lon"] != nil end)
    |> Enum.map(fn ac ->
      %{
        id: "aircraft_#{ac["hex"]}",
        type: "aircraft",
        lat: ac["lat"],
        lng: ac["lon"],
        name: ac["flight"] || ac["registration"] || ac["hex"],
        bearing: ac["track"],
        aircraft_class: ac["class"],
        altitude: ac["alt_baro"],
        speed: ac["gs"],
        registration: ac["registration"],
        aircraft_type: ac["type"]
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
        # Without a name the popup falls back to the literal word "Marker".
        # Bikes have no name upstream, so build a readable one from the id.
        name: "Bike #{String.slice(to_string(bike.bike_id), 0, 8)}",
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
