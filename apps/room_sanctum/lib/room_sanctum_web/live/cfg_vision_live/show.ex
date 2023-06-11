defmodule RoomSanctumWeb.VisionLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 500)
    if connected?(socket), do: Process.send_after(self(), :update_sec, 200)
    {:ok, socket}
  end

  @impl true
  def handle_info(:update_sec, socket) do
    pythiae = Configuration.get_pythiae(:vision, socket.assigns.vision_id)
    {:noreply, socket |> assign(:pythiae, pythiae)}
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
     |> assign(:preview_mode, :basic)
     |> assign(:pythiae, [])
    }
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)
    %{data: data, queries: queries} = RoomSanctum.Worker.Vision.get_state(socket.assigns.vision_id)
    {:noreply, socket |> assign(:preview, data) |> assign(:queries, queries)}
  end

  defp do_toggle(state) do
    case state do
      :basic -> :raw
      :raw -> :basic
    end
  end

  @impl true
  def handle_event("toggle-preview-mode", _params, socket) do
    {:noreply, socket |> assign(:preview_mode, do_toggle(socket.assigns.preview_mode))}
  end

  defp page_title(:show), do: "Vision Detail"
  defp page_title(:edit), do: "Modify Vision"

  defp condense({id, type}, data) do
    RoomSanctum.Condenser.BasicMQTT.condense({id, type}, data)
  end

  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  defp sortert(type) do
    case type do
      :alerts -> 0
      :time -> 1
      :pinned -> 2
      :background -> 3
    end
  end

  defp weekdays do
    [:U, :M, :T, :W, :R, :F, :S]
  end

  defp badge_weekday(current, list) do
    case Enum.member?(list, current) do
      true -> "badge badge-lg badge-primary"
      false -> "badge badge-lg"
    end
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

  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end
end
