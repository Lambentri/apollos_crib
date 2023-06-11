defmodule RoomSanctumWeb.AnkyraLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_info, false)
     |> stream(:ankyras, list_ankyras(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Ankyra")
    |> assign(:ankyra, Accounts.get_rabbit_user!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Register Ankyra")
    |> assign(:ankyra, %RoomSanctum.Accounts.RabbitUser{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Ankyra")
    |> assign(:ankyra, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.AnkyraLive.FormComponent, {:saved, ankyra}}, socket) do
    {:noreply, stream_insert(socket, :ankyras, ankyra)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ankyra = Accounts.get_rabbit_user!(id)
    {:ok, _} = Accounts.delete_rabbit_user!(ankyra)

    {:noreply, stream_delete(socket, :ankyras, ankyra)}
  end

  @impl true
  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  defp list_ankyras(uid) do
    Accounts.list_users_rabbit({:user, uid})
  end
end
