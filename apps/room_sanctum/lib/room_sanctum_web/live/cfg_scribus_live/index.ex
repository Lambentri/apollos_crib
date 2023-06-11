defmodule RoomSanctumWeb.ScribusLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Scribus

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :cfg_scribus, Configuration.list_cfg_scribus())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Scribus")
    |> assign(:scribus, Configuration.get_scribus!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Scribus")
    |> assign(:scribus, %Scribus{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg scribus")
    |> assign(:scribus, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.ScribusLive.FormComponent, {:saved, scribus}}, socket) do
    {:noreply, stream_insert(socket, :cfg_scribus, scribus)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scribus = Configuration.get_scribus!(id)
    {:ok, _} = Configuration.delete_scribus(scribus)

    {:noreply, stream_delete(socket, :cfg_scribus, scribus)}
  end
end
