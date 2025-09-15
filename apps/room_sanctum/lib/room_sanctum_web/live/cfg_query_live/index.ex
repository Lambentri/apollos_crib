defmodule RoomSanctumWeb.QueryLive.Index do
  use RoomSanctumWeb, :live_view_a
  import RoomSanctumWeb.Components.QueryGeospatialMap

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
    end

    {:ok,
     socket
     |> assign(:show_info, false)
     |> assign(:tint, nil)
     |> assign(:view_mode, :table)
     |> assign(:available_tints, available_tints)
     |> assign(:queries, queries)
     |> assign(:vehicle_positions, [])
     |> stream(:cfg_queries, queries)}
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
    IO.inspect("Query Index: Received vehicle positions: #{length(vehicles)}")
    # Filter vehicles to only show those relevant to current queries
    filtered_vehicles = filter_vehicles_for_queries(vehicles, socket.assigns.queries)
    IO.inspect("Query Index: Filtered to: #{length(filtered_vehicles)}")
    {:noreply, socket |> assign(:vehicle_positions, filtered_vehicles)}
  end

  def handle_info(:update_vehicle_positions, socket) do
    # Fetch current vehicle positions from all GTFS sources
    IO.inspect("Query Index: Timer update triggered")
    vehicle_positions = get_all_vehicle_positions(socket.assigns.queries)
    IO.inspect("Query Index: Timer fallback found #{length(vehicle_positions)} vehicles")
    
    # Schedule next update
    Process.send_after(self(), :update_vehicle_positions, 30_000) # Every 30 seconds
    
    {:noreply, socket |> assign(:vehicle_positions, vehicle_positions)}
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
    IO.inspect("=== VEHICLE FILTERING DEBUG ===")
    IO.inspect("Input vehicles count: #{length(vehicles)}")
    IO.inspect("Input queries count: #{length(queries)}")
    
    # Get all trip IDs and route IDs from GTFS queries
    gtfs_queries = queries |> Enum.filter(fn query -> query.source.type == :gtfs end)
    IO.inspect("GTFS queries count: #{length(gtfs_queries)}")
    
    {trip_ids, route_ids, stop_ids} = gtfs_queries
    |> Enum.reduce({[], [], []}, fn query, {trips, routes, stops} ->
      IO.puts("Processing query: #{query.name} with query data: #{inspect(query.query)}")
      case query.query do
        %{stop: stop_id} when is_binary(stop_id) ->
          IO.puts("Found stop query: #{stop_id}")
          stop_trips = RoomSanctum.Storage.get_trips_for_stop(query.source.id, stop_id)
          trip_ids = Enum.map(stop_trips, & &1.trip_id)
          IO.puts("Found #{length(trip_ids)} trips for stop #{stop_id} (first 5: #{Enum.take(trip_ids, 5) |> inspect})")
          {trips ++ trip_ids, routes, [stop_id | stops]}
        %{routes: route_ids} when is_list(route_ids) ->
          IO.puts("Found route query: #{inspect(route_ids)}")
          {trips, routes ++ route_ids, stops}
        _ ->
          IO.puts("Unhandled query type: #{inspect(query.query)}")
          {trips, routes, stops}
      end
    end)
    
    IO.inspect("Final filtering criteria:")
    IO.inspect("Trip IDs count: #{length(trip_ids)} (first 5: #{Enum.take(trip_ids, 5)})")
    IO.inspect("Route IDs count: #{length(route_ids)} (#{inspect(route_ids)})")
    IO.inspect("Stop IDs count: #{length(stop_ids)} (#{inspect(stop_ids)})")
    
    # Sample a few vehicles to see their structure
    sample_vehicles = Enum.take(vehicles, 3)
    IO.inspect("Sample vehicle structures:")
    Enum.each(sample_vehicles, fn vehicle ->
      IO.inspect("Vehicle: trip_id=#{vehicle.trip_id}, route_id=#{vehicle.route_id}, vehicle_id=#{vehicle.vehicle_id}")
    end)
    
    # Filter vehicles that match any of the relevant trips or routes
    filtered_vehicles = vehicles
    |> Enum.filter(fn vehicle ->
      trip_match = vehicle.trip_id && Enum.member?(trip_ids, vehicle.trip_id)
      route_match = vehicle.route_id && Enum.member?(route_ids, vehicle.route_id)
      
      if trip_match || route_match do
        IO.inspect("Vehicle MATCHED: #{vehicle.vehicle_id} (trip: #{vehicle.trip_id}, route: #{vehicle.route_id})")
      end
      
      trip_match || route_match
    end)
    
    IO.inspect("=== FILTERING RESULT: #{length(filtered_vehicles)} vehicles matched ===")
    filtered_vehicles
  end

  # Helper function to get vehicle positions from all GTFS sources
  defp get_all_vehicle_positions(queries) do
    IO.inspect("=== GET ALL VEHICLE POSITIONS DEBUG ===")
    
    source_ids = queries
    |> Enum.filter(fn query -> query.source.type == :gtfs end)
    |> Enum.map(fn query -> query.source.id end)
    |> Enum.uniq()
    
    IO.inspect("Found GTFS source IDs: #{inspect(source_ids)}")
    
    all_vehicles = source_ids
    |> Enum.flat_map(fn source_id ->
      IO.inspect("Fetching vehicles from source #{source_id}")
      try do
        case RoomGtfs.Worker.get_current_vehicle_positions(source_id) do
          vehicles when is_list(vehicles) -> 
            IO.inspect("Source #{source_id} returned #{length(vehicles)} vehicles")
            vehicles
          other -> 
            IO.inspect("Source #{source_id} returned unexpected result: #{inspect(other)}")
            []
        end
      rescue
        e -> 
          IO.inspect("Error fetching from source #{source_id}: #{inspect(e)}")
          []
      catch
        e -> 
          IO.inspect("Caught error fetching from source #{source_id}: #{inspect(e)}")
          []
      end
    end)
    
    IO.inspect("Total vehicles before filtering: #{length(all_vehicles)}")
    filtered_vehicles = all_vehicles |> filter_vehicles_for_queries(queries)
    IO.inspect("=== GET ALL VEHICLE POSITIONS COMPLETE: #{length(filtered_vehicles)} vehicles ===")
    filtered_vehicles
  end

  def get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end
end
