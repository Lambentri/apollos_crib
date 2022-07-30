defmodule RoomSanctumWeb.FociLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Foci

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :focis, list_focis(socket.assigns.current_user.id))}
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

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Register Foci")
    |> assign(:foci, %Foci{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Foci")
    |> assign(:foci, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    foci = Configuration.get_foci!(id)
    {:ok, _} = Configuration.delete_foci(foci)

    {:noreply, assign(socket, :focis, list_focis(socket.assigns.current_user.id))}
  end

  defp list_focis(uid) do
    Configuration.list_focis({:user, uid})
  end
end
