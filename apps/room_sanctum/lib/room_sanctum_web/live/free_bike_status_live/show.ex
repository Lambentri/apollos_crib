defmodule RoomSanctumWeb.FreeBikeStatusLive.Show do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage.GBFS.V1

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:free_bike_status, V1.get_free_bike_status!(id))}
  end

  defp page_title(:show), do: "Show Free bike status"
  defp page_title(:edit), do: "Edit Free bike status"
end
