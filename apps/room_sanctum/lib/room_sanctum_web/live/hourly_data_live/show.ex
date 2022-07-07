defmodule RoomSanctumWeb.HourlyDataLive.Show do
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
     |> assign(:hourly_data, Storage.get_hourly_data!(id))}
  end

  defp page_title(:show), do: "Show Hourly data"
  defp page_title(:edit), do: "Edit Hourly data"
end
