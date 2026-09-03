defmodule RoomSanctumWeb.PlaniLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Plani

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> stream(:plani, Configuration.list_plani(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Plani")
    |> assign(:plani, Configuration.get_plani!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Set a Plani travelling")
    |> assign(:plani, %Plani{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Plani")
    |> assign(:plani, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.PlaniLive.FormComponent, {:saved, plani}}, socket) do
    {:noreply, stream_insert(socket, :plani, plani)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    plani = Configuration.get_plani!(id)
    {:ok, _} = Configuration.delete_plani(plani)

    {:noreply, stream_delete(socket, :plani, plani)}
  end
end
