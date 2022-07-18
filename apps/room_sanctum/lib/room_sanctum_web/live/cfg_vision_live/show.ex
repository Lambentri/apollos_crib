defmodule RoomSanctumWeb.VisionLive.Show do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 1000)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:vision, Configuration.get_vision!(id))
     |> assign(:vision_id, id)
     |> assign(:preview, [])
     |> assign(:queries, [])
    }
  end

  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)
    %{data: data, queries: queries} = RoomSanctum.Worker.Vision.get_state(socket.assigns.vision_id)
    {:noreply, socket |> assign(:preview, data) |> assign(:queries, queries)}
  end

  defp page_title(:show), do: "Show Vision"
  defp page_title(:edit), do: "Edit Vision"

  defp condense({id, type}, data) do
    RoomSanctum.Condenser.BasicMQTT.condense({id, type}, data)
  end
end
