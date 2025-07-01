defmodule RoomSanctumWeb.FociLive.Show do
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
     |> assign(:foci, Configuration.get_foci!(id))}
  end

  defp page_title(:show), do: "Foci Detail"
  defp page_title(:edit), do: "Modify Foci"

  defp getlatlng(%{:place => nil}) do
    nil
  end

  defp getlatlng(%{:place => place}) do
    place |> Map.get(:coordinates, {}) |> Tuple.to_list() |> Poison.encode!()
  end
end
