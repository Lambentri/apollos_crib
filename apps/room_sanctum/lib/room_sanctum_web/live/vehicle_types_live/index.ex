defmodule RoomSanctumWeb.VehicleTypesLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.VehicleTypes

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_vehicle_types, Storage.list_gbfs_vehicle_types())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Vehicle types")
    |> assign(:vehicle_types, Storage.get_vehicle_types!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Vehicle types")
    |> assign(:vehicle_types, %VehicleTypes{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs vehicle types")
    |> assign(:vehicle_types, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.VehicleTypesLive.FormComponent, {:saved, vehicle_types}}, socket) do
    {:noreply, stream_insert(socket, :gbfs_vehicle_types, vehicle_types)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    vehicle_types = Storage.get_vehicle_types!(id)
    {:ok, _} = Storage.delete_vehicle_types(vehicle_types)

    {:noreply, stream_delete(socket, :gbfs_vehicle_types, vehicle_types)}
  end
end
