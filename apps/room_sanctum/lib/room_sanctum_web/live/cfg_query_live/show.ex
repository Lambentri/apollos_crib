defmodule RoomSanctumWeb.QueryLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
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
     |> assign(:type, q.source.type)}
  end

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
      end

    {:noreply, assign(socket, :preview, result)}
  end

  defp page_title(:show), do: "Query Detail"
  defp page_title(:edit), do: "Modify Query"
end
