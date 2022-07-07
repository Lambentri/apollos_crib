defmodule RoomSanctumWeb.ReportingAreaLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.AirNow.ReportingArea

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :airnow_reporting_area, list_airnow_reporting_area())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Reporting area")
    |> assign(:reporting_area, Storage.get_reporting_area!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Reporting area")
    |> assign(:reporting_area, %ReportingArea{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Airnow reporting area")
    |> assign(:reporting_area, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    reporting_area = Storage.get_reporting_area!(id)
    {:ok, _} = Storage.delete_reporting_area(reporting_area)

    {:noreply, assign(socket, :airnow_reporting_area, list_airnow_reporting_area())}
  end

  defp list_airnow_reporting_area do
    Storage.list_airnow_reporting_area()
  end
end
