defmodule RoomSanctumWeb.PythiaeLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Pythiae

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :cfg_pythiae, list_cfg_pythiae(socket.assigns.current_user.id)) |> assign(:show_info, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Pythiae")
    |> assign(:pythiae, Configuration.get_pythiae!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Pythiae")
    |> assign(:pythiae, %Pythiae{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg pythiae")
    |> assign(:pythiae, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    pythiae = Configuration.get_pythiae!(id)
    {:ok, _} = Configuration.delete_pythiae(pythiae)

    {:noreply, assign(socket, :cfg_pythiae, list_cfg_pythiae(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end


  defp list_cfg_pythiae(uid) do
    Configuration.list_cfg_pythiae({:user, uid})
  end
end
