defmodule RoomSanctumWeb.AgencyLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GTFS.Agency

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :agencies, list_agencies())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Agency")
    |> assign(:agency, Storage.get_agency!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Agency")
    |> assign(:agency, %Agency{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Agencies")
    |> assign(:agency, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.AgencyLive.FormComponent, {:saved, agency}}, socket) do
    {:noreply, stream_insert(socket, :agencies, agency)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    agency = Storage.get_agency!(id)
    {:ok, _} = Storage.delete_agency(agency)

    {:noreply, stream_delete(socket, :agencies, agency)}
  end

  defp list_agencies do
    Storage.list_agencies()
  end
end
