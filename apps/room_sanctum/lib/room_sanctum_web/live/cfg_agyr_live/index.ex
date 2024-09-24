defmodule RoomSanctumWeb.AgyrLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Agyr

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :cfg_webhooks, Configuration.list_cfg_webhooks())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Agyr")
    |> assign(:agyr, Configuration.get_agyr!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Agyr")
    |> assign(:agyr, %Agyr{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg webhooks")
    |> assign(:agyr, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.AgyrLive.FormComponent, {:saved, agyr}}, socket) do
    {:noreply, stream_insert(socket, :cfg_webhooks, agyr)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    agyr = Configuration.get_agyr!(id)
    {:ok, _} = Configuration.delete_agyr(agyr)

    {:noreply, stream_delete(socket, :cfg_webhooks, agyr)}
  end
end
