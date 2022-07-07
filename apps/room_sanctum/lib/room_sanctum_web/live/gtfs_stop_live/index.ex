defmodule RoomSanctumWeb.StopLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.Stop

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :stops, list_stops())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Stop")
    |> assign(:stop, Storage.get_stop!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Stop")
    |> assign(:stop, %Stop{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Stops")
    |> assign(:stop, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    stop = Storage.get_stop!(id)
    {:ok, _} = Storage.delete_stop(stop)

    {:noreply, assign(socket, :stops, list_stops())}
  end

  defp list_stops do
    Storage.list_stops()
  end
end
