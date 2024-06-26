defmodule RoomSanctumWeb.ScribusLive.Show do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:scribus, Configuration.get_scribus!(id))}
  end

  defp page_title(:show), do: "Show Scribus"
  defp page_title(:edit), do: "Edit Scribus"
end
