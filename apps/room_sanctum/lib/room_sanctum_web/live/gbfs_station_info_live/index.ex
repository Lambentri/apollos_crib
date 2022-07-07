defmodule RoomSanctumWeb.StationInfoLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.StationInfo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :gbfs_station_information, list_gbfs_station_information())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Station info")
    |> assign(:station_info, Storage.get_station_info!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Station info")
    |> assign(:station_info, %StationInfo{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs station information")
    |> assign(:station_info, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    station_info = Storage.get_station_info!(id)
    {:ok, _} = Storage.delete_station_info(station_info)

    {:noreply, assign(socket, :gbfs_station_information, list_gbfs_station_information())}
  end

  defp list_gbfs_station_information do
    Storage.list_gbfs_station_information()
  end
end
