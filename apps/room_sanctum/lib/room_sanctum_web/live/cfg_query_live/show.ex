defmodule RoomSanctumWeb.QueryLive.Show do
  alias RoomSanctumWeb.Live.Helpers.MapData
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
     |> assign(:query_summaries, %{})
     |> assign(:free_bikes, [])
     |> assign(:gbfs_docks, []) 
     |> assign(:preview_mode, :basic)
     |> assign(:preview_raw, true)
     |> assign(:vehicle_positions, [])
     |> assign(:show_route_lines, false)
     |> assign(:route_lines, [])
     |> assign(:nearby_stations, [])}
  end

  # Built on first use and then kept: the geometry query is not cheap enough to
  # repeat every time the layer is switched back on.
  @impl true
  def handle_event("toggle-route-lines", _params, socket) do
    showing? = not socket.assigns.show_route_lines

    lines =
      case {showing?, socket.assigns.route_lines} do
        {true, []} -> route_lines_for(socket.assigns.query)
        {_, existing} -> existing
      end

    {:noreply,
     socket
     |> assign(:show_route_lines, showing?)
     |> assign(:route_lines, lines)}
  end

  # A stop query is about one stop, so drawing every shape in the feed is
  # useless -- MBTA alone is hundreds of routes. Only the routes that call
  # there get drawn; a query that is not about a stop keeps the whole set,
  # since there is nothing narrower to mean.
  defp route_lines_for(%{source_id: source_id} = query) do
    lines = RoomSanctum.Storage.list_route_lines([source_id])

    case stop_id_of(query) do
      nil ->
        lines

      stop_id ->
        serving =
          source_id
          |> RoomSanctum.Storage.routes_serving_stop(stop_id)
          |> MapSet.new(&"#{source_id}-#{&1}")

        Enum.filter(lines, &MapSet.member?(serving, &1.id))
    end
  end

  # GTFS stop queries key on :stop, GBFS on :stop_id.
  defp stop_id_of(%{query: nil}), do: nil

  defp stop_id_of(%{query: q}) do
    case Map.get(q, :stop) || Map.get(q, :stop_id) do
      value when is_binary(value) -> value
      value when is_integer(value) -> to_string(value)
      _ -> nil
    end
  end

  defp stop_id_of(_), do: nil

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
     # On arrival rather than on the first :update tick, so the page does not
     # come up without the context it is mostly there to show.
     |> assign(:nearby_stations, nearby_stations(q))
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

        :github ->
          level = Map.get(socket.assigns.query.query, :level) || "runs"

          case level do
            "jobs" -> RoomGithub.Worker.read_jobs(socket.assigns.query.source.id, socket.assigns.query.query)
            _ -> RoomGithub.Worker.read_runs(socket.assigns.query.source.id, socket.assigns.query.query)
          end

        :packages ->
          RoomPackages.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :drought ->
          RoomDrought.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :pollen ->
          RoomPollen.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :icarus ->
          RoomIcarus.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :mailbox ->
          RoomHermes.Mail.ImapWorker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :treasury ->
          RoomTreasury.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )

        :bourse ->
          RoomBourse.Worker.read(
            socket.assigns.query.source.id,
            socket.assigns.query.query
          )
      end

    query = socket.assigns.query

    {:noreply,
     socket
     |> assign(:preview, result)
     # The marker's popup says what the preview cards say, from the same
     # condensed data and the same refresh.
     |> assign(:query_summaries, MapData.summaries(query, result))
     |> assign(:free_bikes, MapData.free_bikes_for(query, result))
     |> assign(:gbfs_docks, MapData.stations_for(query, result))
     |> assign(:nearby_stations, nearby_stations(query))}
  end

  # For an air quality query, the answer is one station -- so the neighbours
  # are the context that makes it readable: whether the number is local or the
  # whole city is like that. Ordered closest first, the query's own station
  # leading.
  defp nearby_stations(%{source: %{type: :aqi}} = query) do
    case query.query do
      %{aqsid: aqsid} = q when is_binary(aqsid) and aqsid != "" ->
        case RoomSanctum.Storage.get_aqi_station(query.source_id, aqsid) do
          [station] -> RoomSanctum.Storage.nearby_aqi_stations(query.source_id, station.point, 6)
          _ -> from_foci(query, q)
        end

      %{foci_id: foci_id} when not is_nil(foci_id) ->
        RoomSanctum.Storage.nearest_aqi_stations(query.source_id, foci_id, 6)

      _ ->
        []
    end
  end

  defp nearby_stations(_query), do: []

  # The map speaks stations, not observations.
  defp as_stations(observations) do
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

  defp aqi_of(observation),
    do: RoomSanctum.Storage.AirNow.HourlyObsData.overall_aqi(observation)

  defp from_foci(query, %{foci_id: foci_id}) when not is_nil(foci_id),
    do: RoomSanctum.Storage.nearest_aqi_stations(query.source_id, foci_id, 6)

  defp from_foci(_query, _q), do: []

  def handle_info(:update_sec, socket) do
    visions = Configuration.get_visions(:query, socket.assigns.query_id)
    nv = Configuration.get_visions_nv(:query, socket.assigns.query_id)
    {:noreply, socket |> assign(:visions, visions) |>  assign(:avail_visions, nv)}
  end

  # Handle vehicle position updates
  def handle_info({:vehicle_positions_updated, vehicles}, socket) do
    # Filter vehicles to only show those relevant to current query
    filtered_vehicles = filter_vehicles_for_single_query(vehicles, socket.assigns.query)
#    IO.inspect("Query Show: Filtered #{length(vehicles)} to #{length(filtered_vehicles)} vehicles for stop")
    {:noreply,
     socket
     |> assign(
       :vehicle_positions,
       RoomSanctum.Storage.with_trip_context(filtered_vehicles, socket.assigns.query.source_id)
     )}
  end

  def handle_info(:update_vehicle_positions, socket) do
    # Fetch and filter vehicle positions for this specific query
    if socket.assigns.query.source.type == :gtfs do
      vehicles =
        socket.assigns.query
        |> get_vehicle_positions_for_query()
        |> RoomSanctum.Storage.with_trip_context(socket.assigns.query.source_id)

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

    vision
    |> Configuration.get_vision!()
    |> pin_query(socket)
  end

  # Create a vision around this query, for when the one you want does not exist
  # yet -- otherwise pinning the first query to a new vision means leaving the
  # page, making it, and coming back.
  def handle_event("add-to-new", %{"vision" => %{"name" => name}}, socket) do
    Process.send_after(self(), :update_sec, 200)

    case String.trim(name) do
      "" ->
        {:noreply, put_flash(socket, :error, "Give the vision a name")}

      name ->
        case Configuration.create_vision(%{
               name: name,
               user_id: socket.assigns.current_user.id
             }) do
          {:ok, vision} ->
            pin_query(vision, socket)

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not create #{name}")}
        end
    end
  end

  def handle_event("remove-from", %{"vision" => vision}, socket) do
    Process.send_after(self(), :update_sec, 200)

    vision = Configuration.get_vision!(vision)
    query_id = String.to_integer(socket.assigns.query_id)

    # Both halves again: drop every embed pointing at this query -- there may
    # be more than one, since re-pinning used to duplicate them -- and the id.
    queries =
      vision.queries
      |> Poison.encode!()
      |> Poison.decode!()
      |> Enum.reject(fn q -> to_string(get_in(q, ["data", "query"])) == to_string(query_id) end)

    query_ids = (vision.query_ids || []) -- [query_id]

    case Configuration.update_vision_ni(vision, %{queries: queries, query_ids: query_ids}) do
      {:ok, _vision} ->
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not remove this from #{vision.name}")}
    end
  end

  # A vision records its queries twice: an embedded list that renders, and an
  # id array every "is this query in a vision" lookup reads. Both have to move.
  defp pin_query(vision, socket) do
    query_id = String.to_integer(socket.assigns.query_id)
    existing_ids = vision.query_ids || []

    if query_id in existing_ids do
      {:noreply, socket |> assign(:avail_sel, !socket.assigns.avail_sel)}
    else
      new_query = %{
        id: nil,
        data: %{order: 0, query: socket.assigns.query_id, "__type__": "pinned"},
        type: "pinned"
      }

      queries = (vision.queries |> Poison.encode!() |> Poison.decode!()) ++ [new_query]

      # `||` binds looser than `++`, so `vision.query_ids || [] ++ [id]` read as
      # `query_ids || ([] ++ [id])` and handed back the existing list untouched.
      # The embed grew, the ids did not, and the second query added to any
      # vision silently went nowhere.
      query_ids = existing_ids ++ [query_id]

      case Configuration.update_vision_ni(vision, %{queries: queries, query_ids: query_ids}) do
        {:ok, _vision} ->
          {:noreply, socket |> assign(:avail_sel, !socket.assigns.avail_sel)}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not add this to #{vision.name}")
           |> assign(:avail_sel, !socket.assigns.avail_sel)}
      end
    end
  end

  def handle_event("toggle-preview-mode", _params, socket) do
    {:noreply, socket |> assign(:preview_mode, do_toggle(socket.assigns.preview_mode))}
  end

  def handle_event("toggle-preview-raw", _params, socket) do
    {:noreply, socket |> assign(:preview_raw, !socket.assigns.preview_raw)}
  end

  defp page_title(:show), do: "Query Detail"
  defp page_title(:edit), do: "Modify Query"

  # Raw is no longer a stop on the way round: it is a lens over whichever
  # reading is showing, so the cycle is only the readings themselves.
  defp do_toggle(state) do
    case state do
      :basic -> :plus
      :plus -> :basic
    end
  end

  # The raw view shows the condenser behind the mode you are in, so what you
  # read as JSON is what the card above it was drawn from.
  defp condense_for(:plus, data, key), do: condense_plus(data, key)
  defp condense_for(_mode, data, key), do: condense(data, key)

  defp condense(data, {id, type}) do
    # For preview, use legacy format without query wrapping
    RoomSanctum.Condenser.BasicMQTT.condense_data({id, type}, data)
  end

  defp condense_plus(data, {id, type}) do
    RoomSanctum.Condenser.PlusMQTT.condense_data({id, type}, data)
  end

  defp page_title(:show), do: "Show Query"

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
#    IO.inspect("=== SINGLE QUERY FILTERING DEBUG ===")
#    IO.inspect("Input vehicles count: #{length(vehicles)}")
#    IO.inspect("Query: #{query.name} (#{query.source.type})")
#    IO.inspect("Query data: #{inspect(query.query)}")
    
    result = case query.query do
      %{stop: stop_id} when is_binary(stop_id) ->
#        IO.inspect("Processing stop query for stop_id: #{stop_id}")
        # Get trips that serve this stop
        try do
          stop_trips = RoomSanctum.Storage.get_trips_for_stop(query.source.id, stop_id)
          trip_ids = Enum.map(stop_trips, & &1.trip_id)
#          IO.inspect("Found #{length(trip_ids)} trips serving stop #{stop_id}: #{Enum.take(trip_ids, 10)}")
          
          # Sample some vehicles
          sample_vehicles = Enum.take(vehicles, 5)
#          IO.inspect("Sample vehicle trip_ids: #{Enum.map(sample_vehicles, & &1.trip_id)}")
          
          filtered = vehicles
          |> Enum.filter(fn vehicle ->
            match = vehicle.trip_id && Enum.member?(trip_ids, vehicle.trip_id)
            if match do
#              IO.inspect("MATCHED vehicle: #{vehicle.vehicle_id} on trip #{vehicle.trip_id}")
            end
            match
          end)
          
#          IO.inspect("Stop filtering result: #{length(filtered)} vehicles matched")
          filtered
        rescue
          e -> 
#            IO.inspect("Error getting trips for stop #{stop_id}: #{inspect(e)}")
            []
        end
      %{routes: route_ids} when is_list(route_ids) ->
#        IO.inspect("Processing route query for route_ids: #{inspect(route_ids)}")
        filtered = vehicles
        |> Enum.filter(fn vehicle ->
          match = vehicle.route_id && vehicle.route_id in route_ids
          if match do
#            IO.inspect("MATCHED vehicle: #{vehicle.vehicle_id} on route #{vehicle.route_id}")
          end
          match
        end)
#        IO.inspect("Route filtering result: #{length(filtered)} vehicles matched")
        filtered
      _ ->
#        IO.inspect("Unhandled query type: #{inspect(query.query)}")
        []
    end
    
#    IO.inspect("=== SINGLE QUERY FILTERING COMPLETE: #{length(result)} vehicles ===")
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
