defmodule RoomSanctumWeb.SourceLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Source

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :cfg_sources, list_cfg_sources(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Offering")
    |> assign(:source, Configuration.get_source!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Offering")
    |> assign(:source, %Source{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Offerings")
    |> assign(:source, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    source = Configuration.get_source!(id)
    {:ok, _} = Configuration.delete_source(source)

    {:noreply, assign(socket, :cfg_sources, list_cfg_sources(socket.assigns.current_user.id))}
  end

  defp list_cfg_sources(uid) do
    Configuration.list_cfg_sources({:user, uid})
  end
end
