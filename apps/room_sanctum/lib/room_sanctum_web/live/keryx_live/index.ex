defmodule RoomSanctumWeb.KeryxLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Keryx

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_info, false)
     |> stream(:keryxiae, Configuration.list_keryxiae({:user, socket.assigns.current_user.id}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Keryx")
    |> assign(:keryx, Configuration.get_keryx!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Keryx")
    |> assign(:keryx, %Keryx{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Keryxiae")
    |> assign(:keryx, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.KeryxLive.FormComponent, {:saved, keryx}}, socket) do
    {:noreply, stream_insert(socket, :keryxiae, keryx)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    keryx = Configuration.get_keryx!(id)
    {:ok, _} = Configuration.delete_keryx(keryx)

    {:noreply, stream_delete(socket, :keryxiae, keryx)}
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end
end
