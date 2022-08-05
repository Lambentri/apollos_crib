defmodule RoomSanctumWeb.AnkyraLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:ankyra, Accounts.get_rabbit_user!(id))}
  end

  defp page_title(:show), do: "Ankyra Detail"
  defp page_title(:edit), do: "Modify Ankyra"
end
