defmodule RoomSanctumWeb.TaxidLive.Show do
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
     |> assign(:taxid, Configuration.get_taxid!(id))}
  end

  defp page_title(:show), do: "Show Taxid"
  defp page_title(:edit), do: "Edit Taxid"
end
