defmodule RoomSanctumWeb.StationStatusLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.StationStatus

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_station_status, list_gbfs_station_status())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Station status")
    |> assign(:station_status, Storage.get_station_status!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Station status")
    |> assign(:station_status, %StationStatus{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs station status")
    |> assign(:station_status, nil)
  end

  @impl true
  def handle_info(
        {RoomSanctumWeb.StationStatusLive.FormComponent, {:saved, station_status}},
        socket
      ) do
    {:noreply, stream_insert(socket, :ankyras, station_status)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    station_status = Storage.get_station_status!(id)
    {:ok, _} = Storage.delete_station_status(station_status)

    {:noreply, stream_delete(socket, :gbfs_station_status, station_status)}
  end

  defp list_gbfs_station_status do
    Storage.list_gbfs_station_status()
  end
end
