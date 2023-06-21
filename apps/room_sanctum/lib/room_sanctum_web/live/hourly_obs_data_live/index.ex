defmodule RoomSanctumWeb.HourlyObsDataLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage.AirNow
  alias RoomSanctum.Storage.AirNow.HourlyObsData

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :hourly_observations, list_hourly_observations())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Hourly obs data")
    |> assign(:hourly_obs_data, AirNow.get_hourly_obs_data!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Hourly obs data")
    |> assign(:hourly_obs_data, %HourlyObsData{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Hourly observations")
    |> assign(:hourly_obs_data, nil)
  end

  @impl true
  def handle_info(
        {RoomSanctumWeb.HourlyObsDataLive.FormComponent, {:saved, hourly_obs_data}},
        socket
      ) do
    {:noreply, stream_insert(socket, :hourly_observations, hourly_obs_data)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    hourly_obs_data = AirNow.get_hourly_obs_data!(id)
    {:ok, _} = AirNow.delete_hourly_obs_data(hourly_obs_data)

    {:noreply, stream_delete(socket, :hourly_observations, hourly_obs_data)}
  end

  defp list_hourly_observations do
    AirNow.list_hourly_observations()
  end
end
