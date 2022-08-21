defmodule RoomSanctumWeb.PythiaeLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:pythiae, Configuration.get_pythiae!(id))
     |> assign(:visions, Configuration.list_visions({:user, socket.assigns.current_user.id}))
     |> assign(:foci, Configuration.list_focis({:user, socket.assigns.current_user.id}))
     |> assign(:ankyra, Accounts.list_users_rabbit({:user, socket.assigns.current_user.id}))}
  end

  defp page_title(:show), do: "Show Pythiae"
  defp page_title(:edit), do: "Edit Pythiae"

  def get_by_id(id, array) do
    case array do
      [] -> id
      _anything -> array |> Enum.filter(fn i -> i.id == id end) |> List.first
    end

  end

  def handle_event("do-publish", %{"id" => id}, socket) do
    RoomSanctum.Worker.Pythiae.query_current_now(id)
    {:noreply, socket}
  end
end
