defmodule RoomSanctumWeb.SystemPricingPlansLive.Index do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.GBFS.V1.SystemPricingPlans

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :gbfs_system_pricing_plans, Storage.list_gbfs_system_pricing_plans())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit System pricing plans")
    |> assign(:system_pricing_plans, Storage.get_system_pricing_plans!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New System pricing plans")
    |> assign(:system_pricing_plans, %SystemPricingPlans{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Gbfs system pricing plans")
    |> assign(:system_pricing_plans, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.SystemPricingPlansLive.FormComponent, {:saved, system_pricing_plans}}, socket) do
    {:noreply, stream_insert(socket, :gbfs_system_pricing_plans, system_pricing_plans)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    system_pricing_plans = Storage.get_system_pricing_plans!(id)
    {:ok, _} = Storage.delete_system_pricing_plans(system_pricing_plans)

    {:noreply, stream_delete(socket, :gbfs_system_pricing_plans, system_pricing_plans)}
  end
end
