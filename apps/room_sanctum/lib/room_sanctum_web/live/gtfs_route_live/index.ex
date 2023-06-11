defmodule RoomSanctumWeb.RouteLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.Route

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :routes, list_routes())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Route")
    |> assign(:route, Storage.get_route!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Route")
    |> assign(:route, %Route{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Routes")
    |> assign(:route, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.RouteLive.FormComponent, {:saved, route}}, socket) do
    {:noreply, stream_insert(socket, :routes, route)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    route = Storage.get_route!(id)
    {:ok, _} = Storage.delete_route(route)

    {:noreply, stream_delete(socket, :routes, route)}
  end

  defp list_routes do
    Storage.list_routes()
  end
end
