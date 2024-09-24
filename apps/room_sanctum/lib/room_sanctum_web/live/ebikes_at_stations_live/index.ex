defmodule RoomSanctumWeb.EbikesAtStationsLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.EbikesAtStations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_ebikes_stations, Storage.list_gbfs_ebikes_stations())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Ebikes at stations")
    |> assign(:ebikes_at_stations, Storage.get_ebikes_at_stations!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Ebikes at stations")
    |> assign(:ebikes_at_stations, %EbikesAtStations{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs ebikes stations")
    |> assign(:ebikes_at_stations, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.EbikesAtStationsLive.FormComponent, {:saved, ebikes_at_stations}}, socket) do
    {:noreply, stream_insert(socket, :gbfs_ebikes_stations, ebikes_at_stations)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ebikes_at_stations = Storage.get_ebikes_at_stations!(id)
    {:ok, _} = Storage.delete_ebikes_at_stations(ebikes_at_stations)

    {:noreply, stream_delete(socket, :gbfs_ebikes_stations, ebikes_at_stations)}
  end
end
