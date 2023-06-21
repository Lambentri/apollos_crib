defmodule RoomSanctumWeb.CalendarLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.Calendar

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :calendars, list_calendars())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Calendar")
    |> assign(:calendar, Storage.get_calendar!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Calendar")
    |> assign(:calendar, %Calendar{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Calendars")
    |> assign(:calendar, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.CalendarLive.FormComponent, {:saved, calendar}}, socket) do
    {:noreply, stream_insert(socket, :calendars, calendar)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    calendar = Storage.get_calendar!(id)
    {:ok, _} = Storage.delete_calendar(calendar)

    {:noreply, stream_delete(socket, :calendars, calendar)}
  end

  defp list_calendars do
    Storage.list_calendars()
  end
end
