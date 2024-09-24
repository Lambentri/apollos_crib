defmodule RoomSanctumWeb.GeoFencingZonesLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.GeoFencingZones

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_geofencing_zones, Storage.list_gbfs_geofencing_zones())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Geo fencing zones")
    |> assign(:geo_fencing_zones, Storage.get_geo_fencing_zones!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Geo fencing zones")
    |> assign(:geo_fencing_zones, %GeoFencingZones{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs geofencing zones")
    |> assign(:geo_fencing_zones, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.GeoFencingZonesLive.FormComponent, {:saved, geo_fencing_zones}}, socket) do
    {:noreply, stream_insert(socket, :gbfs_geofencing_zones, geo_fencing_zones)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    geo_fencing_zones = Storage.get_geo_fencing_zones!(id)
    {:ok, _} = Storage.delete_geo_fencing_zones(geo_fencing_zones)

    {:noreply, stream_delete(socket, :gbfs_geofencing_zones, geo_fencing_zones)}
  end
end
