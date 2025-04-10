defmodule RoomSanctumWeb.QueryLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update_sec, 200)
    if connected?(socket), do: Process.send_after(self(), :update, 1000)
    {:ok, socket |> assign(:preview, [])}
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

  def handle_event("toggle-sel", _params, socket) do
    {:noreply, socket |> assign(:avail_sel, !socket.assigns.avail_sel)}
  end

  def handle_event("add-to", %{"vision" => vision}, socket) do
    Process.send_after(self(), :update_sec, 200)
    vis = Configuration.get_vision!(vision)
    new_query = %{id: nil, data: %{order: 0, query: socket.assigns.query_id, "__type__": "pinned"}, type: "pinned"}
    destruct = vis.queries |> Poison.encode!() |> Poison.decode!()
    queries = destruct ++ [new_query]
    new_ids = vis.query_ids ++ [socket.assigns.query_id |> String.to_integer]
    Configuration.update_vision_ni(vis, %{queries: queries, query_ids: new_ids})

    {:noreply, socket |> assign(:avail_sel, !socket.assigns.avail_sel)}
  end

  defp page_title(:show), do: "Query Detail"
  defp page_title(:edit), do: "Modify Query"

  defp package_icon(carrier) do
    case carrier do
      :ups -> "fa-brands fa-ups fa-fw"
      :fedex -> "fa-brands fa-fedex fa-fw"
      :usps -> "fa-brands fa-usps fa-fw"
      _otherwise -> "fa-solid fa-box fa-fw"
    end
  end
end
