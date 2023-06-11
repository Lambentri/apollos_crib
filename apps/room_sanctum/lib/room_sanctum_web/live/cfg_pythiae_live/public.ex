defmodule RoomSanctumWeb.PythiaeLive.Public do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 500)
    {:ok, socket}
  end

  @impl true
  def handle_info(:update_sec, socket) do
    pythiae = Configuration.get_pythiae(:vision, socket.assigns.vision_id)
    {:noreply, socket |> assign(:pythiae, pythiae)}
  end

  defp page_title(:show), do: "Show Pythiae"

  @impl true
  def handle_params(%{"name" => name}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:pythiae, Configuration.get_pythiae!(:name, name))
     |> assign(:preview, [])
     |> assign(:preview_mode, :basic)
     }
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)
    %{data: data, queries: queries} = RoomSanctum.Worker.Vision.get_state(socket.assigns.pythiae.curr_vision)
    {:noreply, socket |> assign(:preview, data) |> assign(:queries, queries)}
  end

  defp condense({id, type}, data) do
    RoomSanctum.Condenser.BasicMQTT.condense({id, type}, data)
  end

  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end

  defp get_query_data(item, queries, size \\ 8) do
    as_map = queries |> Enum.map(fn x -> {x.id, x} end) |> Enum.into(%{})
    case Map.get(as_map, item) do
      nil -> item
      val ->
        case (val.name |> String.length > size) do
        true -> s = val.name |> String.slice(0, size)
                s <> "..."
        false -> val.name
      end
    end
  end

  defp get_query_data_icon(item, queries) do
    as_map = queries |> Enum.map(fn x -> {x.id, x} end) |> Enum.into(%{})
    case Map.get(as_map, item) do
      nil -> ""
      val -> get_icon(val.source.type)
    end
  end
end