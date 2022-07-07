defmodule RoomSanctumWeb.DirectionLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.Direction

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :directions, list_directions())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Direction")
    |> assign(:direction, Storage.get_direction!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Direction")
    |> assign(:direction, %Direction{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Directions")
    |> assign(:direction, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    direction = Storage.get_direction!(id)
    {:ok, _} = Storage.delete_direction(direction)

    {:noreply, assign(socket, :directions, list_directions())}
  end

  defp list_directions do
    Storage.list_directions()
  end
end
