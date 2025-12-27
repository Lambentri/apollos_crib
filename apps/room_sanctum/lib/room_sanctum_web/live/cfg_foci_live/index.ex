defmodule RoomSanctumWeb.FociLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Foci

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_info, false)
     |> stream(:focis, list_focis(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Foci")
    |> assign(:foci, Configuration.get_foci!(id))
  end

  defp apply_action(socket, :edit_coords, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Foci (Coordinates)")
    |> assign(:foci, Configuration.get_foci!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Register Foci")
    |> assign(:foci, %Foci{})
  end

  defp apply_action(socket, :new_coords, _params) do
    socket
    |> assign(:page_title, "Register Foci (Coordinates)")
    |> assign(:foci, %Foci{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Foci")
    |> assign(:foci, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.FociLive.FormComponent, {:saved, foci}}, socket) do
    {:noreply, stream_insert(socket, :focis, foci)}
  end

  @impl true
  def handle_info({RoomSanctumWeb.FociLive.FormComponentCoords, {:saved, foci}}, socket) do
    {:noreply, stream_insert(socket, :focis, foci)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    foci = Configuration.get_foci!(id)
    {:ok, _} = Configuration.delete_foci(foci)

    {:noreply, stream_delete(socket, :focis, foci)}
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  defp list_focis(uid) do
    Configuration.list_focis({:user, uid})
  end
end
