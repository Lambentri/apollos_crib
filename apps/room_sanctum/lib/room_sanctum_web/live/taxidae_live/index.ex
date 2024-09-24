defmodule RoomSanctumWeb.TaxidaeLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.Taxidae

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :storage_mail, Storage.list_storage_mail())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Taxidae")
    |> assign(:taxidae, Storage.get_taxidae!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Taxidae")
    |> assign(:taxidae, %Taxidae{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Storage mail")
    |> assign(:taxidae, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.TaxidaeLive.FormComponent, {:saved, taxidae}}, socket) do
    {:noreply, stream_insert(socket, :storage_mail, taxidae)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    taxidae = Storage.get_taxidae!(id)
    {:ok, _} = Storage.delete_taxidae(taxidae)

    {:noreply, stream_delete(socket, :storage_mail, taxidae)}
  end
end
