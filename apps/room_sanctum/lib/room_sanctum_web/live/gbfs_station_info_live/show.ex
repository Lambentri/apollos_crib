defmodule RoomSanctumWeb.StationInfoLive.Show do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:station_info, Storage.get_station_info!(id))}
  end

  defp page_title(:show), do: "Show Station info"
  defp page_title(:edit), do: "Edit Station info"
end
