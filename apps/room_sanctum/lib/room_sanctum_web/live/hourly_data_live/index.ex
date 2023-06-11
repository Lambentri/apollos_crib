defmodule RoomSanctumWeb.HourlyDataLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.AirNow.HourlyData

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :airnow_hourly_data, list_airnow_hourly_data())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Hourly data")
    |> assign(:hourly_data, Storage.get_hourly_data!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Hourly data")
    |> assign(:hourly_data, %HourlyData{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Airnow hourly data")
    |> assign(:hourly_data, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.HourlyDataLive.FormComponent, {:saved, hourly_data}}, socket) do
    {:noreply, stream_insert(socket, :airnow_hourly_data, hourly_data)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    hourly_data = Storage.get_hourly_data!(id)
    {:ok, _} = Storage.delete_hourly_data(hourly_data)

    {:noreply, stream_delete(socket, :airnow_hourly_data, hourly_data)}
  end

  defp list_airnow_hourly_data do
    Storage.list_airnow_hourly_data()
  end
end
