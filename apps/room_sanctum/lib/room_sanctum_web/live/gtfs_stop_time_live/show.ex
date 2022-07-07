defmodule RoomSanctumWeb.StopTimeLive.Show do
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
     |> assign(:stop_time, Storage.get_stop_time!(id))}
  end

  defp page_title(:show), do: "Show Stop time"
  defp page_title(:edit), do: "Edit Stop time"
end
