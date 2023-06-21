defmodule RoomSanctumWeb.MonitoringSiteLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.AirNow.MonitoringSite

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :airnow_monitoring_sites, list_airnow_monitoring_sites())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Monitoring site")
    |> assign(:monitoring_site, Storage.get_monitoring_site!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Monitoring site")
    |> assign(:monitoring_site, %MonitoringSite{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Airnow monitoring sites")
    |> assign(:monitoring_site, nil)
  end

  @impl true
  def handle_info(
        {RoomSanctumWeb.MonitoringSiteLive.FormComponent, {:saved, monitoring_site}},
        socket
      ) do
    {:noreply, stream_insert(socket, :airnow_monitoring_sites, monitoring_site)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    monitoring_site = Storage.get_monitoring_site!(id)
    {:ok, _} = Storage.delete_monitoring_site(monitoring_site)

    {:noreply, stream_delete(socket, :airnow_monitoring_sites, monitoring_site)}
  end

  defp list_airnow_monitoring_sites do
    Storage.list_airnow_monitoring_sites()
  end
end
