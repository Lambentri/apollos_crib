defmodule RoomSanctumWeb.SourceLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:status, :idle)
      |> assign(:stats, [])
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    source = Configuration.get_source!(id)
    case source.type do
      :gtfs -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs")
      :gbfs -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gbfs")
      :aqi -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "aqi")
    end

    {
      :noreply,
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:source, source)
      |> assign(
           :source_id,
           id
           |> String.to_integer
         )
    }
  end

  defp page_title(:show), do: "Show Offering"
  defp page_title(:edit), do: "Edit Offering"

  def handle_event("do-update", %{"type" => type, "id" => id}, socket) do
    case type do
      "gtfs" ->
        RoomGtfs.Worker.update_static_data(
          id
          |> String.to_integer
        )
      "gbfs" ->
        RoomGbfs.Worker.update_static_data(
          id
          |> String.to_integer
        )
      "aqi" ->
        RoomAirQuality.Worker.update_static_data(
          id
          |> String.to_integer
        )
    end
    {:noreply, socket}
  end

  def handle_event("do-status", _params, socket) do
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      "gtfs",
      {:gtfs, socket.assigns.source_id, :alerts, 1, 3}
    )
    {:noreply, socket}
  end

  def handle_event("do-stats", %{"type" => type, "id" => id}, socket) do
    IO.puts("calc")
    {
      :noreply,
      socket
      |> assign(:stats, socket.assigns.stats ++ ["1", "2", "3", "4", "5"])
    }
  end

  defp percent(num, denom) do
    (num / denom * 100)
    |> Float.floor
  end

  def handle_info({:gbfs, id, file, message} = info, socket) do
    {
      :noreply,
      socket
      |> assign(:status, message)
    }
  end

  def handle_info({:gbfs, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id == id |> String.to_integer do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:gtfs, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id == id |> String.to_integer do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:aqi, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id == id |> String.to_integer do
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
            |> assign(:status, "Retrieving Bundle #{percent(complete, total)}%")
          }
        :parsing ->
          {
            :noreply,
            socket
            |> assign(:status, "Parsing Bundle #{percent(complete, total)}%")
          }
        :extracting ->
          {
            :noreply,
            socket
            |> assign(:status, "Extracting Bundle #{percent(complete, total)}%")
          }
        :error ->
          {
            :noreply,
            socket
            |> assign(:status, "Error downloading/extracting the bundle specified")
          }
        _ ->
          case complete == total do
            true ->
              status = :idle
              {
                :noreply,
                socket
                |> assign(:status, status)
              }
            false ->
              status = "File: '#{file}' #{percent(complete, total)}%"
              {
                :noreply,
                socket
                |> assign(:status, status)
              }
          end
      end
  end
end
