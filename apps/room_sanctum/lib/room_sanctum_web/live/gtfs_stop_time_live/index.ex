defmodule RoomSanctumWeb.StopTimeLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.StopTime

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :stop_times, list_stop_times())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Stop time")
    |> assign(:stop_time, Storage.get_stop_time!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Stop time")
    |> assign(:stop_time, %StopTime{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Stop times")
    |> assign(:stop_time, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    stop_time = Storage.get_stop_time!(id)
    {:ok, _} = Storage.delete_stop_time(stop_time)

    {:noreply, assign(socket, :stop_times, list_stop_times())}
  end

  defp list_stop_times do
    Storage.list_stop_times()
  end
end
