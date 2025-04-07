defmodule RoomSanctumWeb.ScribusLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "scribus:#{id}")
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:preview, nil)
     |> assign(:scribus, Configuration.get_scribus!(id))
     |> assign(:scribus_id, id)}
  end

  def handle_event("toggle-enabled", _params, socket) do
    scribus = socket.assigns.scribus
    {:ok, scribus} = Configuration.update_scribus(scribus, %{enabled: !scribus.enabled})
    {:noreply, socket |> assign(:scribus, scribus)}
  end

  def handle_event("fire", _params, socket) do
    RoomScribe.Worker.request(socket.assigns.scribus_id)
    {:noreply, socket}
  end

  def handle_info({:update, scan_data}, socket) do
    png = scan_data.png |> Base.decode64!
    {:noreply, assign(socket, :preview, "data:image/png;base64, #{scan_data.png}")}
  end

  defp page_title(:show), do: "Show Scribus"
  defp page_title(:edit), do: "Edit Scribus"
end
