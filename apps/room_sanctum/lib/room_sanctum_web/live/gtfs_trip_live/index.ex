defmodule RoomSanctumWeb.TripLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.Trip

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :trips, list_trips())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Trip")
    |> assign(:trip, Storage.get_trip!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Trip")
    |> assign(:trip, %Trip{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Trips")
    |> assign(:trip, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    trip = Storage.get_trip!(id)
    {:ok, _} = Storage.delete_trip(trip)

    {:noreply, assign(socket, :trips, list_trips())}
  end

  defp list_trips do
    Storage.list_trips()
  end
end
