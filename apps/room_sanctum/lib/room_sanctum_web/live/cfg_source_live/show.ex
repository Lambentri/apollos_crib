defmodule RoomSanctumWeb.SourceLive.Show do
  use RoomSanctumWeb, :live_view_a

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
    }
  end

  @impl true
  def handle_info(:update_sec, socket) do
    Process.send_after(self(), :update_sec, 10000)
    queries = Configuration.get_queries(:source, socket.assigns.source_id)
    {:noreply, socket |> assign(:queries, queries)}
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

    case source.type do
      :gtfs -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs")
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

  def get_icon_url(true) do
    "/images/elixir-icon.png"
  end

  def get_icon_url(false) do
    "/assets/img/marker.png"
  end

  def get_first({a, _b}), do: a
  def get_second({_a, b}), do: b
end
