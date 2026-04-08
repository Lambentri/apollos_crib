defmodule RoomSanctumWeb.KeryxLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Set up periodic refresh of cached items
      Process.send_after(self(), :refresh_cache, 1000)
    end
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    keryx = Configuration.get_keryx!(id)
    queries = Configuration.get_queries!(keryx.query_ids)
    cached_items = fetch_cached_items(keryx.id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:keryx, keryx)
     |> assign(:queries, queries)
     |> assign(:cached_items, cached_items)}
  end

  @impl true
  def handle_info(:refresh_cache, socket) do
    Process.send_after(self(), :refresh_cache, 5000)

    cached_items = fetch_cached_items(socket.assigns.keryx.id)

    {:noreply, assign(socket, :cached_items, cached_items)}
  end

  defp fetch_cached_items(keryx_id) do
    try do
      RoomSanctum.Worker.KeryxItemCache.get_all_items(keryx_id)
    rescue
      _ -> %{}
    end
  end

  defp page_title(:show), do: "Show Keryx"
  defp page_title(:edit), do: "Edit Keryx"

  def get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  def format_item_preview(data) do
    try do
      encoded = Jason.encode!(data, pretty: true)
      # Makeup returns an IO list, convert to string and mark as safe HTML
      encoded
      |> Makeup.highlight()
      |> Phoenix.HTML.raw()
    rescue
      Protocol.UndefinedError ->
        # If Jason encoding fails, use inspect as fallback
        inspected = inspect(data, pretty: true, limit: 2048)
        String.slice(inspected, 0..2048) <> if String.length(inspected) > 2048, do: "...", else: ""
    end
  end

  def group_items_by_route_destination(items, type) do
    if type == :gtfs do
      items
      |> Enum.group_by(fn item ->
        {Map.get(item, :route), Map.get(item, :destination)}
      end)
      |> Enum.map(fn {{route, destination}, group_items} ->
        # Get the latest item based on last_seen
        latest = Enum.max_by(group_items, & &1.last_seen, DateTime)

        %{
          route: route,
          destination: destination,
          count: length(group_items),
          last_seen: latest.last_seen,
          first_seen: Enum.min_by(group_items, & &1.first_seen, DateTime).first_seen,
          data: latest.data,
          items: group_items
        }
      end)
      |> Enum.sort_by(fn group -> {group.route, group.destination} end)
    else
      # For non-GTFS, just return items as-is with a wrapper
      items
      |> Enum.map(fn item ->
        %{
          id: item.id,
          count: 1,
          last_seen: item.last_seen,
          first_seen: item.first_seen,
          data: item.data,
          items: [item]
        }
      end)
    end
  end
end
