defmodule RoomSanctumWeb.SysInfoLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.SysInfo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_system_informations, list_gbfs_system_informations())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Sys info")
    |> assign(:sys_info, Storage.get_sys_info!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Sys info")
    |> assign(:sys_info, %SysInfo{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs system informations")
    |> assign(:sys_info, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.SysInfoLive.FormComponent, {:saved, sys_info}}, socket) do
    {:noreply, stream_insert(socket, :gbfs_system_informations, sys_info)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    sys_info = Storage.get_sys_info!(id)
    {:ok, _} = Storage.delete_sys_info(sys_info)

    {:noreply, stream_delete(socket, :gbfs_system_informations, sys_info)}
  end

  defp list_gbfs_system_informations do
    Storage.list_gbfs_system_informations()
  end
end
