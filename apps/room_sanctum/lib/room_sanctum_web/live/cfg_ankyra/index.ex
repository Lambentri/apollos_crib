defmodule RoomSanctumWeb.AnkyraLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:ankyras, list_ankyras(socket.assigns.current_user.id)) |> assign(:show_info, false)}
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
    |> assign(:ankyra, %RabbitUser{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Ankyra")
    |> assign(:ankyra, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ankyra = Accounts.get_rabbit_user!()
    {:ok, _} = Accounts.delete_rabbit_user!(ankyra)

    {:noreply, assign(socket, :ankyras, list_ankyras(socket.assigns.current_user.id))}
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end


  defp list_ankyras(uid) do
    Accounts.list_users_rabbit({:user, uid})
  end
end
