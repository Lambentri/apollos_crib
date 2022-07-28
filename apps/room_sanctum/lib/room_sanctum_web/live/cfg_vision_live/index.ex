defmodule RoomSanctumWeb.VisionLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Vision

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :visions, list_visions(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Vision")
    |> assign(:vision, Configuration.get_vision!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Induce Vision")
    |> assign(:vision, %Vision{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Visions")
    |> assign(:vision, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    vision = Configuration.get_vision!(id)
    {:ok, _} = Configuration.delete_vision(vision)

    {:noreply, assign(socket, :visions, list_visions(socket.assigns.current_user.id))}
  end

  defp list_visions(uid) do
    Configuration.list_visions({:user, uid})
  end
end
