defmodule RoomSanctumWeb.QueryLive.Show do
  use RoomSanctumWeb, :live_view_a
  import RoomSanctumWeb.LivePreview
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update_sec, 200)
    if connected?(socket), do: Process.send_after(self(), :update, 1000)
    
    # Subscribe to vehicle position updates for showing live vehicles  
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs_vehicle_positions")
      Process.send_after(self(), :update_vehicle_positions, 1000)
    end
    
    {:ok, socket 
     |> assign(:preview, []) 
     |> assign(:preview_mode, :basic)
     |> assign(:vehicle_positions, [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    q = Configuration.get_query!(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:query, q)
     |> assign(:query_id, id)
     |> assign(:type, q.source.type)
     |> assign(:visions, [])
     |> assign(:avail_visions, [])
     |> assign(:avail_sel, :false)
    }
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 5000)

    result =
      case socket.assigns.query.source.type do
        :gtfs ->
          RoomGtfs.Worker.query_stop(socket.assigns.query.source.id, socket.assigns.query.query)

        :gbfs ->
          RoomGbfs.Worker.query_stop(socket.assigns.query.source.id, socket.assigns.query.query)

        :tidal ->
          RoomTidal.Worker.query_tides(socket.assigns.query.source.id, socket.assigns.query.query)

        :weather ->
          RoomWeather.Worker.query_weather(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :aqi ->
          RoomAirQuality.Worker.query_place(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :ephem ->
          RoomEphem.Worker.query_ephem(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :calendar ->
          RoomCalendar.Worker.query_calendar(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :cronos ->
          RoomCronos.Worker.query_cronos(
            # we want the query's name here
            socket.assigns.query.id,
            socket.assigns.query.query
          )

        :gitlab ->
          RoomGitlab.Worker.read_jobs(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :packages ->
          RoomPackages.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )
      end

    {:noreply, assign(socket, :preview, result)}
  end

  def handle_info(:update_sec, socket) do
    visions = Configuration.get_visions(:query, socket.assigns.query_id)
    nv = Configuration.get_visions_nv(:query, socket.assigns.query_id)
    {:noreply, socket |> assign(:visions, visions) |>  assign(:avail_visions, nv)}
  end

  # Handle vehicle position updates
  def handle_info({:vehicle_positions_updated, vehicles}, socket) do
    # Filter vehicles to only show those relevant to current query
    filtered_vehicles = filter_vehicles_for_single_query(vehicles, socket.assigns.query)
    IO.inspect("Query Show: Filtered #{length(vehicles)} to #{length(filtered_vehicles)} vehicles for stop")
    {:noreply, socket |> assign(:vehicle_positions, filtered_vehicles)}
  end

  def handle_info(:update_vehicle_positions, socket) do
    # Fetch and filter vehicle positions for this specific query
    if socket.assigns.query.source.type == :gtfs do
      vehicles = get_vehicle_positions_for_query(socket.assigns.query)
      {:noreply, socket |> assign(:vehicle_positions, vehicles)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle-sel", _params, socket) do
    {:noreply, socket |> assign(:avail_sel, !socket.assigns.avail_sel)}
  end

  def handle_event("add-to", %{"vision" => vision}, socket) do
    Process.send_after(self(), :update_sec, 200)
    vis = Configuration.get_vision!(vision)
    new_query = %{id: nil, data: %{order: 0, query: socket.assigns.query_id, "__type__": "pinned"}, type: "pinned"}
    destruct = vis.queries |> Poison.encode!() |> Poison.decode!()
    queries = destruct ++ [new_query]
    new_ids = vis.query_ids || [] ++ [socket.assigns.query_id |> String.to_integer]
    Configuration.update_vision_ni(vis, %{queries: queries, query_ids: new_ids})

    {:noreply, socket |> assign(:avail_sel, !socket.assigns.avail_sel)}
  end

  def handle_event("toggle-preview-mode", _params, socket) do
    {:noreply, socket |> assign(:preview_mode, do_toggle(socket.assigns.preview_mode))}
  end

  defp page_title(:show), do: "Query Detail"
  defp page_title(:edit), do: "Modify Query"

  defp do_toggle(state) do
    case state do
      :basic -> :raw
      :raw -> :basic
    end
  end

  defp condense(data, {id, type}) do
    RoomSanctum.Condenser.BasicMQTT.condense({id, type}, data)
  end

  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end

  defp package_icon(carrier) do
    case carrier do
      :ups -> "fa-brands fa-ups fa-fw"
      :fedex -> "fa-brands fa-fedex fa-fw"
      :usps -> "fa-brands fa-usps fa-fw"
      _otherwise -> "fa-solid fa-box fa-fw"
    end
  end

  # Helper function to filter vehicles for a single query
  defp filter_vehicles_for_single_query(vehicles, query) do
    IO.inspect("=== SINGLE QUERY FILTERING DEBUG ===")
    IO.inspect("Input vehicles count: #{length(vehicles)}")
    IO.inspect("Query: #{query.name} (#{query.source.type})")
    IO.inspect("Query data: #{inspect(query.query)}")
    
    result = case query.query do
      %{stop: stop_id} when is_binary(stop_id) ->
        IO.inspect("Processing stop query for stop_id: #{stop_id}")
        # Get trips that serve this stop
        try do
          stop_trips = RoomSanctum.Storage.get_trips_for_stop(query.source.id, stop_id)
          trip_ids = Enum.map(stop_trips, & &1.trip_id)
          IO.inspect("Found #{length(trip_ids)} trips serving stop #{stop_id}: #{Enum.take(trip_ids, 10)}")
          
          # Sample some vehicles
          sample_vehicles = Enum.take(vehicles, 5)
          IO.inspect("Sample vehicle trip_ids: #{Enum.map(sample_vehicles, & &1.trip_id)}")
          
          filtered = vehicles
          |> Enum.filter(fn vehicle ->
            match = vehicle.trip_id && Enum.member?(trip_ids, vehicle.trip_id)
            if match do
              IO.inspect("MATCHED vehicle: #{vehicle.vehicle_id} on trip #{vehicle.trip_id}")
            end
            match
          end)
          
          IO.inspect("Stop filtering result: #{length(filtered)} vehicles matched")
          filtered
        rescue
          e -> 
            IO.inspect("Error getting trips for stop #{stop_id}: #{inspect(e)}")
            []
        end
      %{routes: route_ids} when is_list(route_ids) ->
        IO.inspect("Processing route query for route_ids: #{inspect(route_ids)}")
        filtered = vehicles
        |> Enum.filter(fn vehicle ->
          match = vehicle.route_id && vehicle.route_id in route_ids
          if match do
            IO.inspect("MATCHED vehicle: #{vehicle.vehicle_id} on route #{vehicle.route_id}")
          end
          match
        end)
        IO.inspect("Route filtering result: #{length(filtered)} vehicles matched")
        filtered
      _ ->
        IO.inspect("Unhandled query type: #{inspect(query.query)}")
        []
    end
    
    IO.inspect("=== SINGLE QUERY FILTERING COMPLETE: #{length(result)} vehicles ===")
    result
  end

  # Helper function to get vehicle positions for a specific query
  defp get_vehicle_positions_for_query(query) do
    try do
      case RoomGtfs.Worker.get_current_vehicle_positions(query.source.id) do
        vehicles when is_list(vehicles) -> 
          filter_vehicles_for_single_query(vehicles, query)
        _ -> 
          []
      end
    rescue
      _ -> []
    catch
      _ -> []
    end
  end
end
