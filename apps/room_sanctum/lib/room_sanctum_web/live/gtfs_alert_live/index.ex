defmodule RoomSanctumWeb.AlertLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.Alert

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :gbfs_alerts, list_gbfs_alerts())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Alert")
    |> assign(:alert, Storage.get_alert!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Alert")
    |> assign(:alert, %Alert{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs alerts")
    |> assign(:alert, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    alert = Storage.get_alert!(id)
    {:ok, _} = Storage.delete_alert(alert)

    {:noreply, assign(socket, :gbfs_alerts, list_gbfs_alerts())}
  end

  defp list_gbfs_alerts do
    Storage.list_gbfs_alerts()
  end
end
