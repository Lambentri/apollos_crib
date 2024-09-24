defmodule RoomSanctumWeb.TaxidLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Taxid

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :cfg_mailboxes, Configuration.list_cfg_mailboxes())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Taxid")
    |> assign(:taxid, Configuration.get_taxid!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Taxid")
    |> assign(:taxid, %Taxid{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg mailboxes")
    |> assign(:taxid, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.TaxidLive.FormComponent, {:saved, taxid}}, socket) do
    {:noreply, stream_insert(socket, :cfg_mailboxes, taxid)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    taxid = Configuration.get_taxid!(id)
    {:ok, _} = Configuration.delete_taxid(taxid)

    {:noreply, stream_delete(socket, :cfg_mailboxes, taxid)}
  end
end
