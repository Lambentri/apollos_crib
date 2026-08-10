defmodule RoomSanctumWeb.QueryLive.Index do
  use RoomSanctumWeb, :live_view_a
  import RoomSanctumWeb.Components.QueryGeospatialMap
  alias RoomSanctumWeb.Live.Helpers.MapStreaming

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Query

  @impl true
  def mount(_params, _session, socket) do
    queries = list_cfg_queries(socket.assigns.current_user.id)
    available_tints = get_available_tints(queries)

    # Subscribe to vehicle position updates for all GTFS sources
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs_vehicle_positions")
      Process.send_after(self(), :update_vehicle_positions, 1000)
      
      # Always use high-performance streaming for all map data
      Task.start_link(fn ->
        stream_map_queries(self(), queries)
      end)
    end

    {:ok,
     socket
     |> assign(:show_info, false)
     |> assign(:tint, nil)
     |> assign(:view_mode, :table)
     |> assign(:available_tints, available_tints)
     |> assign(:queries, queries)
     |> assign(:vehicle_positions, [])
     |> assign(:aircraft, [])
     # Off by default: this map is about the user's queries, and a couple of
     # area queries in different cities bury them under live traffic.
     |> assign(:show_aircraft, false)
     |> assign(:show_route_lines, false)
     |> assign(:route_lines, [])
     |> stream(:cfg_queries, queries)}
  end

  # The index spans sources, so this covers every GTFS source with a query on
  # the map. Built on first use and then kept.
  @impl true
  def handle_event("toggle-route-lines", _params, socket) do
    showing? = not socket.assigns.show_route_lines

    lines =
      case {showing?, socket.assigns.route_lines} do
        {true, []} ->
          socket.assigns.queries
          |> Enum.filter(&(&1.source && &1.source.type == :gtfs))
          |> Enum.map(& &1.source_id)
          |> RoomSanctum.Storage.list_route_lines()

        {_, existing} ->
          existing
      end

    {:noreply,
     socket
     |> assign(:show_route_lines, showing?)
     |> assign(:route_lines, lines)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Query")
    |> assign(:query, Configuration.get_query!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Make a Query")
    |> assign(:query, %Query{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Queries")
    |> assign(:query, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.QueryLive.FormComponent, {:saved, query}}, socket) do
    queries = list_cfg_queries(socket.assigns.current_user.id)
    available_tints = get_available_tints(queries)
    
    {:noreply, 
     socket
     |> assign(:available_tints, available_tints)
     |> assign(:queries, queries)
     |> stream_insert(:cfg_queries, query)}
  end

  def handle_info({:vehicle_positions_updated, vehicles}, socket) do
#    IO.inspect("Query Index: Received vehicle positions: #{length(vehicles)}")
    # Filter vehicles to only show those relevant to current queries
    filtered_vehicles = filter_vehicles_for_queries(vehicles, socket.assigns.queries)
#    IO.inspect("Query Index: Filtered to: #{length(filtered_vehicles)}")
    {:noreply, socket |> assign(:vehicle_positions, filtered_vehicles)}
  end

  def handle_info(:update_vehicle_positions, socket) do
    # Fetch current vehicle positions from all GTFS sources
#    IO.inspect("Query Index: Timer update triggered")
    vehicle_positions = get_all_vehicle_positions(socket.assigns.queries)
#    IO.inspect("Query Index: Timer fallback found #{length(vehicle_positions)} vehicles")
    
    # Schedule next update
    Process.send_after(self(), :update_vehicle_positions, 30_000) # Every 30 seconds
    
    {:noreply,
     socket
     |> assign(:vehicle_positions, vehicle_positions)
     |> assign(:aircraft, refresh_aircraft(socket.assigns))}
  end

  def handle_event("toggle-aircraft", _params, socket) do
    showing? = not socket.assigns.show_aircraft

    {:noreply,
     socket
     |> assign(:show_aircraft, showing?)
     |> assign(:aircraft, if(showing?, do: get_all_aircraft(socket.assigns.queries), else: []))}
  end

  defp refresh_aircraft(%{show_aircraft: true, queries: queries}), do: get_all_aircraft(queries)
  defp refresh_aircraft(_assigns), do: []

  # One read per icarus query, so each contributes the aircraft it actually
  # matches -- its own radius, altitude band and class filters -- rather than
  # everything its source can see. The worker answers from cache between its
  # own refreshes, and an absent one contributes nothing.
  defp get_all_aircraft(queries) do
    if Code.ensure_loaded?(RoomIcarus.Worker) do
      queries
      |> Enum.filter(&(&1.source && &1.source.type == :icarus))
      |> Enum.flat_map(fn query ->
        try do
          RoomIcarus.Worker.read(query.source_id, query.query)
        catch
          :exit, _ -> []
        end
      end)
      |> RoomSanctumWeb.Components.QueryGeospatialMap.aircraft_from_preview_list()
      |> Enum.uniq_by(& &1["hex"])
    else
      []
    end
  end

  # Handle streaming map data batches for high-performance rendering
  def handle_info({:map_data_batch, compressed_data, batch_num}, socket) do
    socket = push_event(socket, "add_markers_batch", %{
      compressed_data: compressed_data,
      batch: batch_num
    })
    
    {:noreply, socket}
  end

  # Handle streaming completion
  def handle_info({:map_streaming_complete}, socket) do
    socket = push_event(socket, "map_streaming_complete", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    query = Configuration.get_query!(id)
    {:ok, _} = Configuration.delete_query(query)

    {:noreply, stream_delete(socket, :cfg_queries, query)}
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  def handle_event("toggle-view", _params, socket) do
    new_mode = case socket.assigns.view_mode do
      :table -> :map
      :map -> :table
    end
    
    {:noreply, socket |> assign(:view_mode, new_mode)}
  end

  def handle_event("set-tint", %{"tint"=> tint}, socket) do
    IO.inspect({"set-tint", tint, socket.assigns.tint})
    queries = case socket.assigns.tint == tint do
      true -> 
        list_cfg_queries(socket.assigns.current_user.id)
      false -> 
        list_cfg_queries(socket.assigns.current_user.id, tint)
    end
    
    new_tint = if socket.assigns.tint == tint, do: nil, else: tint
    
    {:noreply, socket 
     |> assign(:tint, new_tint) 
     |> assign(:queries, queries)
     |> stream(:cfg_queries, queries, reset: true)}
  end

  defp list_cfg_queries(uid) do
    Configuration.list_cfg_queries({:user, uid})
  end

  defp list_cfg_queries(uid, tint) do
    Configuration.list_cfg_queries({:user, uid}) |> Enum.filter(fn q -> 
      (q.meta && q.meta.tint == tint) || (q.source && q.source.meta && q.source.meta.tint == tint)
    end)
  end

  defp get_available_tints(queries) do
    queries
    |> Enum.flat_map(fn query ->
      tints = []
      
      # Add query tint if it exists
      tints = if query.meta && query.meta.tint do
        [query.meta.tint | tints]
      else
        tints
      end
      
      # Add source tint if it exists  
      tints = if query.source && query.source.meta && query.source.meta.tint do
        [query.source.meta.tint | tints]
      else
        tints
      end
      
      tints
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Helper function to filter vehicles based on query relevance
  defp filter_vehicles_for_queries(vehicles, queries) do
#    IO.inspect("=== VEHICLE FILTERING DEBUG ===")
#    IO.inspect("Input vehicles count: #{length(vehicles)}")
#    IO.inspect("Input queries count: #{length(queries)}")
    
    # Get all trip IDs and route IDs from GTFS queries
    gtfs_queries = queries |> Enum.filter(fn query -> query.source.type == :gtfs end)
#    IO.inspect("GTFS queries count: #{length(gtfs_queries)}")
    
    {trip_ids, route_ids, stop_ids} = gtfs_queries
    |> Enum.reduce({[], [], []}, fn query, {trips, routes, stops} ->
#      IO.puts("Processing query: #{query.name} with query data: #{inspect(query.query)}")
      case query.query do
        %{stop: stop_id} when is_binary(stop_id) ->
#          IO.puts("Found stop query: #{stop_id}")
          stop_trips = RoomSanctum.Storage.get_trips_for_stop(query.source.id, stop_id)
          trip_ids = Enum.map(stop_trips, & &1.trip_id)
#          IO.puts("Found #{length(trip_ids)} trips for stop #{stop_id} (first 5: #{Enum.take(trip_ids, 5) |> inspect})")
          {trips ++ trip_ids, routes, [stop_id | stops]}
        %{routes: route_ids} when is_list(route_ids) ->
#          IO.puts("Found route query: #{inspect(route_ids)}")
          {trips, routes ++ route_ids, stops}
        _ ->
#          IO.puts("Unhandled query type: #{inspect(query.query)}")
          {trips, routes, stops}
      end
    end)
    
#    IO.inspect("Final filtering criteria:")
#    IO.inspect("Trip IDs count: #{length(trip_ids)} (first 5: #{Enum.take(trip_ids, 5)})")
#    IO.inspect("Route IDs count: #{length(route_ids)} (#{inspect(route_ids)})")
#    IO.inspect("Stop IDs count: #{length(stop_ids)} (#{inspect(stop_ids)})")
    
    # Sample a few vehicles to see their structure
    sample_vehicles = Enum.take(vehicles, 3)
#    IO.inspect("Sample vehicle structures:")
    Enum.each(sample_vehicles, fn vehicle ->
#      IO.inspect("Vehicle: trip_id=#{vehicle.trip_id}, route_id=#{vehicle.route_id}, vehicle_id=#{vehicle.vehicle_id}")
    end)
    
    # Filter vehicles that match any of the relevant trips or routes
    filtered_vehicles = vehicles
    |> Enum.filter(fn vehicle ->
      trip_match = vehicle.trip_id && Enum.member?(trip_ids, vehicle.trip_id)
      route_match = vehicle.route_id && Enum.member?(route_ids, vehicle.route_id)
      
      if trip_match || route_match do
#        IO.inspect("Vehicle MATCHED: #{vehicle.vehicle_id} (trip: #{vehicle.trip_id}, route: #{vehicle.route_id})")
      end
      
      trip_match || route_match
    end)
    
#    IO.inspect("=== FILTERING RESULT: #{length(filtered_vehicles)} vehicles matched ===")
    filtered_vehicles
  end

  # Helper function to get vehicle positions from all GTFS sources
  defp get_all_vehicle_positions(queries) do
#    IO.inspect("=== GET ALL VEHICLE POSITIONS DEBUG ===")
    
    source_ids = queries
    |> Enum.filter(fn query -> query.source.type == :gtfs end)
    |> Enum.map(fn query -> query.source.id end)
    |> Enum.uniq()
    
#    IO.inspect("Found GTFS source IDs: #{inspect(source_ids)}")
    
    all_vehicles = source_ids
    |> Enum.flat_map(fn source_id ->
#      IO.inspect("Fetching vehicles from source #{source_id}")
      try do
        case RoomGtfs.Worker.get_current_vehicle_positions(source_id) do
          vehicles when is_list(vehicles) ->
            # Per source: a trip_id only means anything within its own feed.
            vehicles = RoomSanctum.Storage.with_trip_context(vehicles, source_id)

#            IO.inspect("Source #{source_id} returned #{length(vehicles)} vehicles")
            vehicles
          other -> 
#            IO.inspect("Source #{source_id} returned unexpected result: #{inspect(other)}")
            []
        end
      rescue
        e -> 
#          IO.inspect("Error fetching from source #{source_id}: #{inspect(e)}")
          []
      catch
        e -> 
#          IO.inspect("Caught error fetching from source #{source_id}: #{inspect(e)}")
          []
      end
    end)
    
#    IO.inspect("Total vehicles before filtering: #{length(all_vehicles)}")
    filtered_vehicles = all_vehicles |> filter_vehicles_for_queries(queries)
#    IO.inspect("=== GET ALL VEHICLE POSITIONS COMPLETE: #{length(filtered_vehicles)} vehicles ===")
    filtered_vehicles
  end

  def get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  # Stream map queries for high-performance rendering
  defp stream_map_queries(pid, queries) do
    # Convert queries to mappable format and stream them
    mappable_queries = queries
    |> Enum.map(&convert_query_to_map_format/1)
    |> Enum.filter(fn query -> 
      query.lat && query.lng && query.lat != 0 && query.lng != 0 
    end)

    total_queries = length(mappable_queries)
    
    # Always use streaming for consistent performance
    if total_queries > 0 do
      MapStreaming.stream_map_data(
        pid, 
        fn offset, limit ->
          mappable_queries
          |> Enum.drop(offset)
          |> Enum.take(limit)
        end,
        batch_size: 500,
        total_records: total_queries,
        compress: true
      )
    end
  end

  # Convert query to map format for streaming
  defp convert_query_to_map_format(query) do
    {lat, lng} = extract_query_coordinates(query)
    
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
      notes: query.notes
    }
  end

  # Extract coordinates from query (simplified version of QueryGeospatialMap logic)
  defp extract_query_coordinates(query) do
    cond do
      query.geom != nil ->
        case query.geom do
          %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
          _ -> {0, 0}
        end
        
      query.source && has_source_coordinates?(query.source) ->
        extract_source_coordinates(query.source)

      query.query && extract_from_query_data_simple(query) ->
        extract_from_query_data_simple(query)
        
      true -> {0, 0}
    end
  end

  defp has_source_coordinates?(source) do
    geom = Map.get(source, :geom, nil)
    lat = Map.get(source, :lat, nil)
    lng = Map.get(source, :lng, nil)
    
    geom != nil || (lat != nil && lng != nil)
  end

  defp extract_source_coordinates(source) do
    geom = Map.get(source, :geom, nil)
    lat = Map.get(source, :lat, nil)
    lng = Map.get(source, :lng, nil)
    
    cond do
      geom != nil ->
        case geom do
          %Geo.Point{coordinates: {lng, lat}} -> {lat, lng}
          _ -> {0, 0}
        end
      lat != nil && lng != nil ->
        {lat, lng}
      true -> {0, 0}
    end
  end

  defp extract_from_query_data_simple(query) do
    # Simplified version - just return false for now to avoid complexity
    # The full QueryGeospatialMap component handles this better
    false
  end
end
