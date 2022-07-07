defmodule RoomSanctumWeb.StationStatusLive.Show do
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
     |> assign(:station_status, Storage.get_station_status!(id))}
  end

  defp page_title(:show), do: "Show Station status"
  defp page_title(:edit), do: "Edit Station status"
end
