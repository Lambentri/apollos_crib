defmodule RoomSanctumWeb.FreeBikeStatusLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage.GBFS.V1
  alias RoomSanctum.Storage.GBFS.V1.FreeBikeStatus

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_free_bike_status, V1.list_gbfs_free_bike_status())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Free bike status")
    |> assign(:free_bike_status, V1.get_free_bike_status!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Free bike status")
    |> assign(:free_bike_status, %FreeBikeStatus{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs free bike status")
    |> assign(:free_bike_status, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.FreeBikeStatusLive.FormComponent, {:saved, free_bike_status}}, socket) do
    {:noreply, stream_insert(socket, :gbfs_free_bike_status, free_bike_status)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    free_bike_status = V1.get_free_bike_status!(id)
    {:ok, _} = V1.delete_free_bike_status(free_bike_status)

    {:noreply, stream_delete(socket, :gbfs_free_bike_status, free_bike_status)}
  end
end
