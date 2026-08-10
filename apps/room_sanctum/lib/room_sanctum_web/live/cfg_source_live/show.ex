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
      |> assign(:vehicle_positions, [])
      |> assign(:free_bikes, [])
      |> assign(:stations, [])
      # Both are otherwise only set by the :update_sec tick 200ms in, so any
      # view touching them could be rendered before they exist.
      |> assign(:station_statuses, [])
      |> assign(:source_tint, nil)
      # Route geometry is off until asked for: building it walks stop_times,
      # and on a full feed it is hundreds of polylines.
      |> assign(:show_route_lines, false)
      |> assign(:route_lines, [])
      |> assign(:route_types, %{})
      # Route ids calling at the stop the tester has selected, so its map can
      # show that stop's routes rather than the whole system's.
      |> assign(:tester_route_ids, [])
      |> assign(:view_mode, :system)
      # Same palette the query form offers, so a tint picked here and one
      # picked there are drawn from the same set. Every entry needs its
      # bg-<tint>-500 to survive Tailwind's purge -- the literal swatches in
      # cfg_query_live/form_component.html.heex are what keep them alive.
      |> assign(:tint_opts, ~w(amber lime emerald sky violet fuchsia rose stone slate))
      |> assign(:gitlab_config_open, false)
      |> assign(:gitlab_available_projects, [])
      |> assign(:github_config_open, false)
      |> assign(:github_available_repos, [])
      |> assign(:treasury_from, nil)
      |> assign(:treasury_to, nil)
      |> assign(:treasury_preview, nil)
      |> assign(:bourse_symbol, nil)
      |> assign(:bourse_preview, nil)
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

    # Stations for the map. GTFS stops carry stop_lat/stop_lon/stop_name where
    # GBFS uses lat/lon/name, so they are normalised to one shape rather than
    # teaching the map component two vocabularies.
    stations = case socket.assigns.source.type do
      :gbfs -> Storage.list_gbfs_station_information(socket.assigns.source_id)
      :gtfs -> socket.assigns.source_id |> Storage.list_stops() |> Enum.map(&stop_as_station/1)
      _ -> []
    end

    # Add station status for GBFS sources
    station_statuses = case socket.assigns.source.type do
      :gbfs -> Storage.list_gbfs_station_status(socket.assigns.source_id)
      _ -> []
    end

    # Vehicle positions name a route, not a vehicle kind; the type comes from
    # the route table.
    route_types = case socket.assigns.source.type do
      :gtfs -> Storage.route_types(socket.assigns.source_id)
      _ -> %{}
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
     |> assign(:route_types, route_types)
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

    source_id = String.to_integer(id)

    # Queries were previously only loaded by the :update_sec tick 200ms after
    # mount, so the card rendered empty on arrival -- which the bulk paint view
    # would announce as "no queries yet" before correcting itself.
    queries = Configuration.get_queries(:source, source_id)

    {
      :noreply,
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:source, source)
      |> assign(:source_id, source_id)
      |> assign(:queries, queries)
      |> assign(:available_tints, get_available_tints(queries))
    }
  end

  # format_stations/3 reaches for :place directly, so every key it touches has
  # to be present -- a plain map without :place raises rather than falling
  # through to the lat/lon branch.
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

  # GTFS queries key on :stop, GBFS on :stop_id.
  defp station_id_of(%{query: nil}), do: nil
  defp station_id_of(%{query: q}), do: Map.get(q, :stop_id) || Map.get(q, :stop)
  defp station_id_of(_), do: nil

  defp page_title(:show), do: "Offering Detail"
  defp page_title(:edit), do: "Modify Offering"



  # Create a query straight from a station marker's popup. Named after the
  # station so the query is recognisable without opening it.
  @impl true
  def handle_event("map-add-query", %{"station-id" => station_id} = params, socket) do
    name = Map.get(params, "name") || "Station #{station_id}"

    if station_id in queried_station_ids(socket) do
      {:noreply, put_flash(socket, :error, "#{name} already has a query")}
    else
      add_station_query(socket, station_id, name)
    end
  end

  # The station ids this source already has queries for, so the map can grey
  # them out and a second click cannot stack a duplicate.
  defp queried_station_ids(socket) do
    socket.assigns.queries
    |> Enum.map(&station_id_of/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
  end

  # GTFS names the field :stop, GBFS :stop_id.
  defp station_query_for(:gtfs, id), do: %{"__type__" => "gtfs", "stop" => id}
  defp station_query_for(type, id), do: %{"__type__" => to_string(type), "stop_id" => id}

  defp add_station_query(socket, station_id, name) do
    case Configuration.create_query(%{
           user_id: socket.assigns.current_user.id,
           source_id: socket.assigns.source.id,
           name: name,
           query: station_query_for(socket.assigns.source.type, station_id),
           public: true
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:queries, Configuration.get_queries(:source, socket.assigns.source_id))
         |> put_flash(:info, "Added query #{name}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add a query for #{name}")}
    end
  end

  # --- bourse symbol builder -------------------------------------------

  @impl true
  def handle_event("bourse-look", %{"sym" => %{"symbol" => symbol}}, socket) do
    symbol = symbol |> to_string() |> String.trim() |> String.upcase()

    preview =
      case {symbol, RoomBourse.Worker.pid(socket.assigns.source_id)} do
        {"", _} -> nil
        {_, nil} -> nil
        {sym, _pid} -> RoomBourse.Worker.read(socket.assigns.source_id, %{symbol: sym}) |> List.first()
      end

    {:noreply,
     socket
     |> assign(:bourse_symbol, if(symbol == "", do: nil, else: symbol))
     |> assign(:bourse_preview, preview)}
  end

  def handle_event("bourse-add", _params, socket) do
    case socket.assigns.bourse_symbol do
      nil ->
        {:noreply, put_flash(socket, :error, "Enter a symbol first.")}

      symbol ->
        # Prefer the name Yahoo returned, so the query reads "Apple Inc."
        name =
          case socket.assigns.bourse_preview do
            %{name: n} when is_binary(n) and n != "" -> n
            _ -> symbol
          end

        case Configuration.create_query(%{
               user_id: socket.assigns.current_user.id,
               source_id: socket.assigns.source.id,
               name: name,
               query: %{"__type__" => "bourse", "symbol" => symbol},
               public: true
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:queries, Configuration.get_queries(:source, socket.assigns.source_id))
             |> put_flash(:info, "Added query #{name}")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not add #{symbol}")}
        end
    end
  end

  # --- treasury pair builder -------------------------------------------
  # Same shape as the transit stop tester: choose, see the live number, then
  # keep it as a query if it reads right.

  @impl true
  def handle_event("treasury-pick", %{"pair" => %{"from" => from, "to" => to}}, socket) do
    {:noreply,
     socket
     |> assign(:treasury_from, blank_to_nil(from))
     |> assign(:treasury_to, blank_to_nil(to))
     |> preview_treasury()}
  end

  def handle_event("treasury-swap", _params, socket) do
    {:noreply,
     socket
     |> assign(:treasury_from, socket.assigns.treasury_to)
     |> assign(:treasury_to, socket.assigns.treasury_from)
     |> preview_treasury()}
  end

  def handle_event("treasury-add", _params, socket) do
    from = socket.assigns.treasury_from
    to = socket.assigns.treasury_to

    if is_nil(from) or is_nil(to) do
      {:noreply, put_flash(socket, :error, "Pick both sides first.")}
    else
      name = "#{String.upcase(from)}/#{String.upcase(to)}"

      case Configuration.create_query(%{
             user_id: socket.assigns.current_user.id,
             source_id: socket.assigns.source.id,
             name: name,
             query: %{"__type__" => "treasury", "from" => from, "to" => to},
             public: true
           }) do
        {:ok, _q} ->
          {:noreply,
           socket
           |> assign(:queries, Configuration.get_queries(:source, socket.assigns.source_id))
           |> put_flash(:info, "Added query #{name}")}

        {:error, _cs} ->
          {:noreply, put_flash(socket, :error, "Could not add #{name}")}
      end
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp preview_treasury(%{assigns: %{treasury_from: f, treasury_to: t}} = socket)
       when is_binary(f) and is_binary(t) do
    result =
      case RoomTreasury.Worker.pid(socket.assigns.source_id) do
        nil -> nil
        _pid -> RoomTreasury.Worker.read(socket.assigns.source_id, %{from: f, to: t}) |> List.first()
      end

    assign(socket, :treasury_preview, result)
  end

  defp preview_treasury(socket), do: assign(socket, :treasury_preview, nil)

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
      "gitlab-jobs" ->
        RoomGitlab.Worker.query_jobs(id, %{})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("gitlab-open-config", _params, socket) do
    id = socket.assigns.source_id
    available =
      case RoomGitlab.Worker.pid(id) do
        nil -> []
        _pid -> RoomGitlab.Worker.read_available_projects(id) || []
      end

    {:noreply,
     socket
     |> assign(:gitlab_config_open, true)
     |> assign(:gitlab_available_projects, available)}
  end

  @impl true
  def handle_event("gitlab-close-config", _params, socket) do
    {:noreply, socket |> assign(:gitlab_config_open, false)}
  end

  @impl true
  def handle_event("gitlab-refresh-projects", _params, socket) do
    id = socket.assigns.source_id
    RoomGitlab.Worker.query_projects(id)
    Process.send_after(self(), :gitlab_reload_available, 1500)
    {:noreply, socket |> put_flash(:info, "Refreshing projects from GitLab...")}
  end

  @impl true
  def handle_event("gitlab-toggle-project", %{"id" => project_id}, socket) do
    {:noreply, socket |> toggle_watched(:projects, to_string(project_id))}
  end

  @impl true
  def handle_event("gitlab-toggle-namespace", %{"path" => path}, socket) do
    {:noreply, socket |> toggle_watched(:namespaces, path)}
  end

  defp toggle_watched(socket, key, value) do
    source = socket.assigns.source
    current = (Map.get(source.config, key) || []) |> Enum.map(&to_string/1)

    new_list =
      if value in current do
        List.delete(current, value)
      else
        [value | current]
      end

    case RoomSanctum.Configuration.update_source_config(source, %{key => new_list}) do
      {:ok, updated} -> socket |> assign(:source, updated)
      {:error, _changeset} -> socket |> put_flash(:error, "Failed to update watched #{key}")
    end
  end

  defp ensure_watched(socket, key, value) do
    source = socket.assigns.source
    current = (Map.get(source.config, key) || []) |> Enum.map(&to_string/1)

    if value in current do
      socket
    else
      case RoomSanctum.Configuration.update_source_config(source, %{key => [value | current]}) do
        {:ok, updated} ->
          kick_gitlab_worker(updated.id)
          socket |> assign(:source, updated)

        {:error, _changeset} ->
          socket
      end
    end
  end

  defp kick_gitlab_worker(source_id) do
    case RoomGitlab.Worker.pid(source_id) do
      nil ->
        :ok

      _pid ->
        RoomGitlab.Worker.refresh_db_cfg(source_id)
        RoomGitlab.Worker.query_jobs(source_id, %{})
    end
  end

  defp kick_github_worker(source_id) do
    case RoomGithub.Worker.pid(source_id) do
      nil ->
        :ok

      _pid ->
        RoomGithub.Worker.refresh_db_cfg(source_id)
        RoomGithub.Worker.query_runs(source_id)
        RoomGithub.Worker.query_jobs(source_id)
    end
  end

  defp ensure_watched_github(socket, key, value) do
    source = socket.assigns.source
    current = (Map.get(source.config, key) || []) |> Enum.map(&to_string/1)

    if value in current do
      socket
    else
      case RoomSanctum.Configuration.update_source_config(source, %{key => [value | current]}) do
        {:ok, updated} ->
          kick_github_worker(updated.id)
          socket |> assign(:source, updated)

        {:error, _changeset} ->
          socket
      end
    end
  end

  defp toggle_watched_github(socket, key, value) do
    source = socket.assigns.source
    current = (Map.get(source.config, key) || []) |> Enum.map(&to_string/1)

    new_list =
      if value in current do
        List.delete(current, value)
      else
        [value | current]
      end

    case RoomSanctum.Configuration.update_source_config(source, %{key => new_list}) do
      {:ok, updated} ->
        kick_github_worker(updated.id)
        socket |> assign(:source, updated)

      {:error, _changeset} ->
        socket |> put_flash(:error, "Failed to update watched #{key}")
    end
  end

  @impl true
  def handle_event("github-open-config", _params, socket) do
    id = socket.assigns.source_id

    available =
      case RoomGithub.Worker.pid(id) do
        nil -> []
        _pid -> RoomGithub.Worker.read_available_repos(id) || []
      end

    {:noreply,
     socket
     |> assign(:github_config_open, true)
     |> assign(:github_available_repos, available)}
  end

  @impl true
  def handle_event("github-close-config", _params, socket) do
    {:noreply, socket |> assign(:github_config_open, false)}
  end

  @impl true
  def handle_event("github-refresh-repos", _params, socket) do
    id = socket.assigns.source_id
    RoomGithub.Worker.query_repos(id)
    Process.send_after(self(), :github_reload_available, 1500)
    {:noreply, socket |> put_flash(:info, "Refreshing repos from GitHub...")}
  end

  @impl true
  def handle_event("github-toggle-repo", %{"full_name" => full}, socket) do
    {:noreply, socket |> toggle_watched_github(:repos, full)}
  end

  @impl true
  def handle_event("github-toggle-owner", %{"owner" => owner}, socket) do
    {:noreply, socket |> toggle_watched_github(:owners, owner)}
  end

  @impl true
  def handle_event("github-query-repo", %{"full_name" => full} = params, socket) do
    socket = socket |> ensure_watched_github(:repos, full)
    kick_github_worker(socket.assigns.source.id)

    level = Map.get(params, "level", "runs")

    case RoomSanctum.Configuration.create_query(%{
           user_id: socket.assigns.current_user.id,
           source_id: socket.assigns.source.id,
           name: full,
           query: %{
             "__type__" => "github",
             "repo" => full,
             "level" => level,
             "status" => "in_progress,queued"
           },
           public: true
         }) do
      {:ok, _query} ->
        {:noreply, socket |> put_flash(:info, "Query created for #{full}")}

      {:error, _cs} ->
        {:noreply, socket |> put_flash(:error, "Failed to create query for #{full}")}
    end
  end

  @impl true
  def handle_event("github-query-owner", %{"owner" => owner} = params, socket) do
    socket = socket |> ensure_watched_github(:owners, owner)
    kick_github_worker(socket.assigns.source.id)

    level = Map.get(params, "level", "runs")

    case RoomSanctum.Configuration.create_query(%{
           user_id: socket.assigns.current_user.id,
           source_id: socket.assigns.source.id,
           name: owner,
           query: %{
             "__type__" => "github",
             "owner" => owner,
             "level" => level,
             "status" => "in_progress,queued"
           },
           public: true
         }) do
      {:ok, _query} ->
        {:noreply, socket |> put_flash(:info, "Query created for owner #{owner}")}

      {:error, _cs} ->
        {:noreply, socket |> put_flash(:error, "Failed to create query for #{owner}")}
    end
  end

  @impl true
  def handle_event("gitlab-query-project", %{"id" => id, "name" => name} = params, socket) do
    socket = socket |> ensure_watched(:projects, to_string(id))
    kick_gitlab_worker(socket.assigns.source.id)

    case RoomSanctum.Configuration.create_query(%{
           user_id: socket.assigns.current_user.id,
           source_id: socket.assigns.source.id,
           name: name,
           query: %{
             "__type__" => "gitlab",
             "id" => String.to_integer(to_string(id)),
             "statuses" => Map.get(params, "statuses", "running")
           },
           public: true
         }) do
      {:ok, _query} ->
        {:noreply, socket |> put_flash(:info, "Query created for project #{name}")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to create query for #{name}")}
    end
  end

  @impl true
  def handle_event("gitlab-query-namespace", %{"path" => path} = params, socket) do
    socket = socket |> ensure_watched(:namespaces, path)
    kick_gitlab_worker(socket.assigns.source.id)

    case RoomSanctum.Configuration.create_query(%{
           user_id: socket.assigns.current_user.id,
           source_id: socket.assigns.source.id,
           name: path,
           query: %{
             "__type__" => "gitlab",
             "namespace" => path,
             "statuses" => Map.get(params, "statuses", "running")
           },
           public: true
         }) do
      {:ok, _query} ->
        {:noreply, socket |> put_flash(:info, "Query created for namespace #{path}")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to create query for #{path}")}
    end
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
#    IO.inspect({type, id})

    stats =
      case type do
        "gtfs" ->
          stats = RoomGtfs.Worker.source_stats(id)
          rt_flat = stats.rt
            |> Enum.flat_map(fn {feed, info} ->
              case info do
                m when is_map(m) -> Enum.map(m, fn {k, v} -> {:"#{feed}_#{k}", v} end)
                other            -> [{feed, other}]
              end
            end)
            |> Map.new()
          %{gtfs: Map.delete(stats, :rt), rt: rt_flat}
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
    {:noreply, socket |> assign(:tester, !socket.assigns.tester)}
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
    serving =
      case socket.assigns.source.type do
        :gtfs -> Storage.routes_serving_stop(socket.assigns.source_id, val)
        _ -> []
      end

    {:noreply,
     socket
     |> assign(:tester_selected, val)
     |> assign(:tester_selected_name, name)
     |> assign(:tester_route_ids, serving)}
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
          
      {:gtfs, "vehicle"} ->
        # For GTFS vehicle position queries, create a vehicle tracking query
        Configuration.create_query(
          %{
            user_id: socket.assigns.current_user.id,
            source_id: socket.assigns.source.id,
            name: "#{name}",
            query: %{"vehicle_id" => station_id, "__type__" => "gtfs_vehicle_positions"},
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
  # Paste a tracking number, or the text of a shipping email, to register it by
  # hand -- the same extraction the mail queue runs, without waiting for a poll.
  def handle_event("submit-pkg", %{"submit" => %{"query" => query}}, socket) do
    source_id = socket.assigns.source_id

    flash =
      case RoomSanctum.Queues.Mail.extract_tracking(query) |> Enum.at(0) do
        nil ->
          {:error, "No tracking number recognised in that text."}

        {:ups, numbers} ->
          ag = RoomSanctum.Configuration.get_agyr!(:src, source_id, "ups_webhook")
          RoomSanctum.Queues.Mail.register_ups(numbers, ag)
          {:info, "Registered #{count(numbers)} with UPS."}

        {:usps, numbers} ->
          source = Configuration.get_source!(source_id)

          if RoomPackages.USPS.configured?(source) do
            RoomSanctum.Queues.Mail.register_usps(numbers, source_id)
            {:info, "Tracking #{count(numbers)} with USPS. Status appears within a minute."}
          else
            {:error, "Add USPS API credentials to this offering first."}
          end

        {carrier, _numbers} ->
          {:error, "Detected #{carrier}, but that carrier is not implemented yet."}
      end

    socket =
      case flash do
        {:info, msg} -> put_flash(socket, :info, msg)
        {:error, msg} -> put_flash(socket, :error, msg)
      end

    {:noreply, socket |> assign(:source, Configuration.get_source!(source_id))}
  end

  defp count(numbers) do
    n = length(List.wrap(numbers))
    "#{n} number#{if n == 1, do: "", else: "s"}"
  end

  def handle_event("set-tint", %{"tint"=> tint}, socket) do
#    IO.inspect({"set-tint", tint, socket.assigns.tint})
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
      # Leaving bulk paint by the other button lands on the map, which is
      # where the tints just set are actually visible.
      :paint -> :detail
    end
    {:noreply, socket |> assign(:view_mode, new_mode)}
  end

  # Built on first use and then kept: the query is not cheap enough to repeat
  # every time the layer is switched back on.
  def handle_event("toggle-route-lines", _params, socket) do
    showing? = not socket.assigns.show_route_lines

    lines =
      case {showing?, socket.assigns.route_lines} do
        {true, []} -> Storage.list_route_lines(socket.assigns.source_id)
        {_, existing} -> existing
      end

    {:noreply,
     socket
     |> assign(:show_route_lines, showing?)
     |> assign(:route_lines, lines)}
  end

  def handle_event("toggle-paint", _params, socket) do
    new_mode = if socket.assigns.view_mode == :paint, do: :system, else: :paint
    {:noreply, socket |> assign(:view_mode, new_mode)}
  end

  # Painting writes through immediately rather than collecting a form: the
  # point of the view is working down a list of queries, and a save step you
  # can forget would silently lose the whole pass.
  def handle_event("paint-query", %{"query-id" => id} = params, socket) do
    tint = case Map.get(params, "tint") do
      "" -> nil
      value -> value
    end

    query = Enum.find(socket.assigns.queries, &(to_string(&1.id) == to_string(id)))

    case query && Configuration.update_query(query, %{"meta" => %{"tint" => tint}}) do
      {:ok, _updated} ->
        queries = Configuration.get_queries(:source, socket.assigns.source_id)

        {:noreply,
         socket
         |> assign(:queries, queries)
         |> assign(:available_tints, get_available_tints(queries))}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Could not set that tint")}

      nil ->
        {:noreply, socket}
    end
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

  @impl true
  def handle_info(:gitlab_reload_available, socket) do
    if socket.assigns.gitlab_config_open and socket.assigns.source.type == :gitlab do
      id = socket.assigns.source_id

      available =
        case RoomGitlab.Worker.pid(id) do
          nil -> []
          _pid -> RoomGitlab.Worker.read_available_projects(id) || []
        end

      {:noreply, socket |> assign(:gitlab_available_projects, available)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:github_reload_available, socket) do
    if socket.assigns.github_config_open and socket.assigns.source.type == :github do
      id = socket.assigns.source_id

      available =
        case RoomGithub.Worker.pid(id) do
          nil -> []
          _pid -> RoomGithub.Worker.read_available_repos(id) || []
        end

      {:noreply, socket |> assign(:github_available_repos, available)}
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
    RoomSanctum.Condenser.BasicMQTT.condense_data({id, type}, data)
  end
  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end

  defp getlatlng(coords) do
    coords |> Tuple.to_list() |> Poison.encode!()
  end

  # How far either side of the picked stop the tester map shows its
  # neighbours. Roughly a kilometre, which is enough to place a stop on its
  # street without dragging in the rest of the system.
  @tester_area_degrees 0.01

  # Everything the map draws carries its position differently: GBFS stations
  # put a Geo.Point in :place, free bikes in :point, GTFS stops are normalised
  # to :lat/:lon by stop_as_station/1, and realtime vehicles use the spelled
  # out :latitude/:longitude.
  defp map_coords(item) do
    cond do
      match?(%Geo.Point{}, Map.get(item, :place)) -> from_geo(Map.get(item, :place))
      match?(%Geo.Point{}, Map.get(item, :point)) -> from_geo(Map.get(item, :point))
      pair(item, :lat, :lon) -> pair(item, :lat, :lon)
      pair(item, :latitude, :longitude) -> pair(item, :latitude, :longitude)
      true -> nil
    end
  end

  defp from_geo(%Geo.Point{coordinates: {lon, lat}}), do: {lat, lon}

  defp pair(item, lat_key, lon_key) do
    lat = Map.get(item, lat_key)
    lon = Map.get(item, lon_key)
    if is_number(lat) and is_number(lon), do: {lat, lon}, else: nil
  end

  defp tester_focus_station(_stations, nil), do: nil

  defp tester_focus_station(stations, selected_id) do
    Enum.find(stations, fn station ->
      to_string(station.station_id) == to_string(selected_id)
    end)
  end

  # The tester is looking at one stop, so the whole feed's geometry is noise:
  # keep only the routes that call there. A pure filter over lines already
  # loaded, so it costs nothing on the tester's 2s re-render.
  defp lines_for_stop(lines, route_ids) do
    serving = MapSet.new(route_ids)
    Enum.filter(lines, &MapSet.member?(serving, &1.id))
  end

  defp within_area(items, {lat, lon}) do
    Enum.filter(items, fn item ->
      case map_coords(item) do
        {ilat, ilon} ->
          abs(ilat - lat) <= @tester_area_degrees and abs(ilon - lon) <= @tester_area_degrees

        nil ->
          false
      end
    end)
  end

  # The radio itself is sr-only, so the swatch carries the whole selected/not
  # signal. A ring alone would be easy to miss against nine circles, hence the
  # dimming of the unselected ones as well as the check drawn inside the
  # chosen swatch.
  defp swatch_class(selected?) do
    base = "flex items-center justify-center w-7 h-7 rounded-full"

    case selected? do
      true -> base <> " ring-2 ring-offset-2 ring-offset-base-100 ring-base-content"
      # Dimmed enough to recede behind the selected swatch, but not so far that
      # the colours stop being tellable apart -- picking one is the whole job.
      _ -> base <> " opacity-70 hover:opacity-100"
    end
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

end
