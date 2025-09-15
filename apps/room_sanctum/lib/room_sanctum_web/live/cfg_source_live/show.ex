defmodule RoomSanctumWeb.SourceLive.Show do
  use RoomSanctumWeb, :live_view_a
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update_sec, 200)
    if connected?(socket), do: Process.send_after(self(), :update_tester, 200)

    {
      :ok,
      socket
      |> assign(:status, :idle)
      |> assign(:status_val, 0)
      |> assign(:stats, %{})
      |> assign(:queries, [])
      |> assign(:tint, nil)
      |> assign(:available_tints, [])
      |> assign(:tester, false)
      |> assign(:tester_query, nil)
      |> assign(:tester_results, [])
      |> assign(:tester_selected, nil)
      |> assign(:tester_selected_name, nil)
      |> assign(:tester_selected_data, %{})
      |> assign(:tester_foci_distance, 100)
      |> assign(:tester_foci_coords, {42.3736, -71.1097})
      |> assign(:tester_foci_coords_lat, 42.3736)
      |> assign(:tester_foci_coords_lon, -71.1097)
      |> assign(:tester_foci, {})
      |> assign(:tester_foci_vehicles, [])
      |> assign(:vehicle_positions, [])
      |> assign(:free_bikes, [])
      |> assign(:stations, [])
      |> assign(:view_mode, :system)
    }
  end

  @impl true
  def handle_info(:update_sec, socket) do
    Process.send_after(self(), :update_sec, 10000)
    queries = Configuration.get_queries(:source, socket.assigns.source_id)
    available_tints = get_available_tints(queries)
    
    # Add free bikes for GBFS sources
    free_bikes = case socket.assigns.source.type do
      :gbfs -> Storage.list_gbfs_free_bike_status() 
               |> Enum.filter(&(&1.source_id == socket.assigns.source_id))
      _ -> []
    end

    # Add station information for GBFS sources
    stations = case socket.assigns.source.type do
      :gbfs -> Storage.list_gbfs_station_information(socket.assigns.source_id)
      _ -> []
    end

    # Add station status for GBFS sources
    station_statuses = case socket.assigns.source.type do
      :gbfs -> Storage.list_gbfs_station_status(socket.assigns.source_id)
      _ -> []
    end

    # Extract source tint for stations
    source_tint = if socket.assigns.source.meta && socket.assigns.source.meta.tint do
      socket.assigns.source.meta.tint
    else
      nil
    end
    
    {:noreply, socket 
     |> assign(:queries, queries)
     |> assign(:available_tints, available_tints)
     |> assign(:free_bikes, free_bikes)
     |> assign(:stations, stations)
     |> assign(:station_statuses, station_statuses)
     |> assign(:source_tint, source_tint)}
  end

  @impl true
  def handle_info(:update_tester, socket) do
    Process.send_after(self(), :update_tester, 2000)
    case socket.assigns.tester_selected do
      nil -> {:noreply, socket}
      _otherwise ->
        data = case socket.assigns.source.type do
          :gtfs -> RoomGtfs.Worker.query_stop(socket.assigns.source.id, %{stop: socket.assigns.tester_selected})
          :gbfs -> RoomGbfs.Worker.query_stop(socket.assigns.source.id, %{stop_id: socket.assigns.tester_selected})
        end
        {:noreply, socket |> assign(:tester_selected_data, data)}
    end


  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    source = Configuration.get_source!(id) |> IO.inspect

    # Subscribe to relevant PubSub channels
    case source.type do
      :gtfs -> 
        Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs")
        Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs_vehicle_positions:#{id}")
        if connected?(socket), do: Process.send_after(self(), :update_vehicle_positions, 1000)
      :gbfs -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gbfs")
      :aqi -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "aqi")
      :calendar -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "ical")
      _default -> :ok
    end

    {
      :noreply,
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:source, source)
      |> assign(
        :source_id,
        id
        |> String.to_integer()
      )
    }
  end

  defp page_title(:show), do: "Offering Detail"
  defp page_title(:edit), do: "Modify Offering"

  @impl true
  def handle_event("do-update", %{"type" => type, "id" => id}, socket) do
    id =
      id
      |> String.to_integer()

    case type do
      "gtfs" ->
        RoomGtfs.Worker.update_static_data(id)

      "gbfs" ->
        RoomGbfs.Worker.update_static_data(id)

      "aqi" ->
        RoomAirQuality.Worker.update_static_data(id)

      "ical" ->
        RoomCalendar.Worker.update_static_data(id)
      "gitlab-projects" ->
        RoomGitlab.Worker.query_projects(id)
      "gitlab-commits" ->
        RoomGitlab.Worker.query_commits(id)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("do-status", _params, socket) do
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      "gtfs",
      {:gtfs, socket.assigns.source_id, :alerts, 1, 3}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("do-stats", %{"type" => type, "id" => id}, socket) do
    IO.inspect({type, id})

    stats =
      case type do
        "gtfs" -> %{gtfs: RoomGtfs.Worker.source_stats(id), rt: %{}}
        "gbfs" -> %{gbfs: RoomGbfs.Worker.source_stats(id), system: RoomGbfs.Worker.sys_info_as_stats(id), free: RoomGbfs.Worker.free_stats(id)}
        _otherwise -> %{}
      end

    {
      :noreply,
      socket
      |> assign(:stats, stats)
    }
  end

  def handle_event("toggle-source-enabled", _params, socket) do
    src = socket.assigns.source
    {:ok, source} = Configuration.update_source(src, %{enabled: !src.enabled})
    {:noreply, socket |> assign(:source, source)}
  end

  @impl true
  def handle_event("add-tester", _params, socket) do
    foci = Configuration.list_focis({:user,socket.assigns.current_user.id})
    {:noreply, socket |> assign(:tester, !socket.assigns.tester) |> assign(:tester_foci, foci)}
  end

  @impl true
  def handle_event("do-gbfs-search", %{"name" => name, "id" => id}, socket) do
    results = Storage.list_gbfs_station_information(id, name)
    {:noreply, socket |> assign(:tester_results, results)}
  end

  def handle_event("do-gtfs-search", %{"name" => name, "id" => id}, socket) do
    results = Storage.list_stops(id, name)
    {:noreply, socket |> assign(:tester_results, results)}
  end

  @impl true
  def handle_event("pick-result", %{"id" => val, "name" => name}, socket) do
    {:noreply, socket |> assign(:tester_selected, val) |> assign(:tester_selected_name, name)}
  end

  @impl true
  def handle_event("add-query", _params, socket) do
    case socket.assigns.source.type do
      :gbfs -> Configuration.create_query(
                %{
                  user_id: socket.assigns.current_user.id,
                  source_id: socket.assigns.source.id,
                  name: socket.assigns.tester_selected_name,
                  query: %{"stop_id": socket.assigns.tester_selected, "__type__": "gbfs"},
                  public: true
                }) |> IO.inspect
      :gtfs -> Configuration.create_query(
                 %{
                   user_id: socket.assigns.current_user.id,
                   source_id: socket.assigns.source.id,
                   name: socket.assigns.tester_selected_name,
                   query: %{"stop": socket.assigns.tester_selected, "__type__": "gtfs"},
                   public: true
                 }) |> IO.inspect
    end

    {:noreply, socket |> assign(:tester_selected, nil) |> assign(:tester_selected_name, nil)}
  end

  @impl true
  def handle_event("add-query-from-map", %{"station_id" => station_id, "name" => name, "type" => type}, socket) do
    case {socket.assigns.source.type, type} do
      {:gbfs, "station"} -> 
        Configuration.create_query(
          %{
            user_id: socket.assigns.current_user.id,
            source_id: socket.assigns.source.id,
            name: "#{name} - Station Query",
            query: %{"stop_id" => station_id, "__type__" => "gbfs"},
            public: true
          }) |> IO.inspect
          
      {:gbfs, "area"} ->
        # For free bike area queries, create a radius-based query around the bike location
        # We'll use a default 500m radius, but this could be made configurable
        bike = Enum.find(socket.assigns.free_bikes, &(&1.bike_id == station_id))
        if bike do
          Configuration.create_query(
            %{
              user_id: socket.assigns.current_user.id,
              source_id: socket.assigns.source.id,
              name: "Free Bikes around #{bike.lat}, #{bike.lon}",
              query: %{
                "lat" => bike.lat,
                "lng" => bike.lon,
                "radius" => 500,  # 500 meter radius
                "__type__" => "gbfs"
              },
              public: true
            }) |> IO.inspect
        end
        
      {:gtfs, "stop"} ->
        Configuration.create_query(
          %{
            user_id: socket.assigns.current_user.id,
            source_id: socket.assigns.source.id,
            name: "#{name} - Stop Query",
            query: %{"stop" => station_id, "__type__" => "gtfs"},
            public: true
          }) |> IO.inspect
          
      {_, "query"} ->
        # For duplicating existing queries, find the original and copy it
        original_query = Enum.find(socket.assigns.queries, &(&1.id == String.to_integer(station_id)))
        if original_query do
          Configuration.create_query(
            %{
              user_id: socket.assigns.current_user.id,
              source_id: socket.assigns.source.id,
              name: "Copy of #{original_query.name}",
              query: original_query.query,
              public: true
            }) |> IO.inspect
        end
        
      _ -> 
        IO.inspect("Unhandled query creation for type: #{type}, source: #{socket.assigns.source.type}")
    end
    
    # Show a temporary success message or update
    {:noreply, socket |> put_flash(:info, "Query created successfully!")}
  end

  @impl true
  def handle_event("select-foci", %{"foci" => foci, "distance" => distance} = data, socket) do
    IO.inspect(data)
    [lat, lon] = foci |> String.split(",") |> Enum.map(&String.to_float/1)
    point = %Geo.Point{coordinates: {lat, lon}, srid: 4326}
    vehicles = Storage.find_free_bikes_around_point(socket.assigns.source_id, point, distance |> String.to_integer) |> IO.inspect
    {:noreply, socket
               |> assign(:tester_foci_distance, distance)
               |> assign(:tester_foci_coords, {lat, lon})
               |> assign(:tester_foci_coords_lat, lat)
               |> assign(:tester_foci_coords_lon, lon)
               |> assign(:tester_foci_vehicles, vehicles)
    }
  end

  def handle_event("submit-pkg", %{"submit" =>%{"query" => query}} = data, socket) do
    q = RoomSanctum.Queues.Mail.extract_tracking(query)
    {typ, number} = Enum.at(q, 0)

    case typ do
      :ups ->
         ag = RoomSanctum.Configuration.get_agyr!(:src, socket.assigns.source_id, "ups_webhook")
         RoomSanctum.Queues.Mail.register_ups(number, ag)
      typp -> IO.inspect("unhandled typ, #{typp}")
    end
    #IO.inspect(query)
    {:noreply, socket}
  end

  def handle_event("set-tint", %{"tint"=> tint}, socket) do
    IO.inspect({"set-tint", tint, socket.assigns.tint})
    case socket.assigns.tint == tint do
      true -> {:noreply, socket |> assign(:tint, nil)}
      false -> {:noreply, socket |> assign(:tint, tint)}
    end
  end

  @impl true
  def handle_event("toggle-view", _params, socket) do
    new_mode = case socket.assigns.view_mode do
      :system -> :detail
      :detail -> :system
    end
    {:noreply, socket |> assign(:view_mode, new_mode)}
  end

  defp percent(num, denom) do
    (num / denom * 100)
    |> Float.floor()
  end

  @impl true
  def handle_info({:gbfs, id, file, message} = info, socket) do
    {
      :noreply,
      socket
      |> assign(:status, message)
    }
  end

  @impl true
  def handle_info({:gbfs, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id ==
         id
         |> String.to_integer() do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({type, id, :disabled} = info, socket) do
    {:noreply, socket |> put_flash(:info, "Updates will not fire while disabled")}
  end

  @impl true
  def handle_info({type, id, :done} = info, socket) do
    source = Configuration.get_source!(socket.assigns.source_id)
    {:noreply, socket |> assign(:source, source) |> put_flash(:info, "Completed")}
  end

  # Handle vehicle position updates for source-specific display
  @impl true
  def handle_info({:vehicle_positions_updated, source_id, vehicles}, socket) do
    if socket.assigns.source_id == source_id do
      {:noreply, socket |> assign(:vehicle_positions, vehicles)}
    else
      {:noreply, socket}
    end
  end

  # Fallback timer for vehicle position updates
  @impl true
  def handle_info(:update_vehicle_positions, socket) do
    Process.send_after(self(), :update_vehicle_positions, 30000)
    
    case socket.assigns.source.type do
      :gtfs ->
        vehicles = RoomGtfs.Worker.get_current_vehicle_positions(socket.assigns.source_id)
        {:noreply, socket |> assign(:vehicle_positions, vehicles)}
      _ ->
        {:noreply, socket}
    end
  end


  @impl true
  def handle_info({:gtfs, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id ==
         id
         |> String.to_integer() do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:aqi, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id ==
         id
         |> String.to_integer() do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  def gen_pct(file, complete, total, socket) do
    case file do
      :downloading ->
        {
          :noreply,
          socket
          |> assign(:status, "Retrieving Bundle")
          |> assign(:status_val, percent(complete, total))
        }

      :parsing ->
        {
          :noreply,
          socket
          |> assign(:status, "Parsing Bundle")
          |> assign(:status_val, percent(complete, total))
        }

      :extracting ->
        {
          :noreply,
          socket
          |> assign(:status, "Extracting Bundle")
          |> assign(:status_val, percent(complete, total))
        }

      :error ->
        {
          :noreply,
          socket
          |> assign(:status, "Error downloading/extracting the bundle specified")
          |> assign(:status_val, 0)
        }

      _ ->
        case complete == total do
          true ->
            status = :idle

            {
              :noreply,
              socket
              |> assign(:status, status)
              |> assign(:status_val, 0)
            }

          false ->
            status = "File: '#{file}'"

            {
              :noreply,
              socket
              |> assign(:status, status)
              |> assign(:status_val, percent(complete, total))
            }
        end
    end
  end

  defp get_icon(source_type) do
    RoomSanctumWeb.IconHelpers.icon(source_type)
  end

  defp icon_code(source_type) do
    RoomSanctumWeb.IconHelpers.icon_code(source_type)
  end

  defp is_updated(source_meta) do
    case source_meta |> Map.get(:last_run) do
      nil -> "NEVER"
      val -> val # |> Timex.format!("%Y-%m-%d @ %H:%M", :strftime)
    end
  end

  defp condense({id, type}, data) do
    RoomSanctum.Condenser.BasicMQTT.condense({id, type}, data)
  end
  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end

  defp pt_for_form({lat, lon}) do
      "#{lat},#{lon}"
  end

  defp getlatlng(coords) do
    coords |> Tuple.to_list() |> Poison.encode!()
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

  defp filter_queries_by_tint(queries, nil), do: queries
  defp filter_queries_by_tint(queries, tint) do
    queries
    |> Enum.filter(fn query ->
      (query.meta && query.meta.tint == tint) || 
      (query.source && query.source.meta && query.source.meta.tint == tint)
    end)
  end

  def get_icon_url(true) do
    "/images/elixir-icon.png"
  end

  def get_icon_url(false) do
    "/assets/img/marker.png"
  end

  def get_first({a, _b}), do: a
  def get_second({_a, b}), do: b
end
