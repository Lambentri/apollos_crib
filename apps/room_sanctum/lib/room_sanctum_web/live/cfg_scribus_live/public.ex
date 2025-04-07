defmodule RoomSanctumWeb.ScribusLive.Public do
  use RoomSanctumWeb, :live_view_ca

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :clock, 10); Process.send_after(self(), :update, 500)
    {:ok, socket}
  end

  @impl true
  def handle_info(:update_sec, socket) do
    scribus = Configuration.get_scribus!(:vision, socket.assigns.scribus_id)
    [w,h] = scribus.resolution |> String.split("x")
    {:noreply, socket |> assign(:scribus, scribus) |> assign(:width, w) |> assign(:height, h)}
  end

  @impl true
  def handle_info(:clock, socket) do
    Process.send_after(self(), :clock, 1000)
    tz = socket.assigns.scribus.tz || "UTC"
    time = DateTime.now!(tz) |> DateTime.to_time
    {:noreply, socket |> assign(:time, time)}
  end

  defp page_title(:show), do: "Show Scribus"

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    scribus = Configuration.get_scribus!(id)
    [w,h] = scribus.resolution |> String.split("x")
    {:noreply,
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:scribus, scribus)
      |> assign(:scribus_id, id)
      |> assign(:curr_vision, "Pending")
      |> assign(:preview, [])
      |> assign(:preview_mode, :basic)
      |> assign(:time, nil)
      |> assign(:w, "#{w}px")
      |> assign(:h, "#{h}px")
    }
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)

    %{data: data, queries: queries, name: name} =
      RoomSanctum.Worker.Vision.get_state(socket.assigns.scribus.vision)

    {:noreply, socket |> assign(:preview, data) |> assign(:queries, queries) |> assign(:curr_vision, name)}
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
      nil ->
        item

      val ->
        case val.name |> String.length() > size do
          true ->
            s = val.name |> String.slice(0, size)
            s <> "..."

          false ->
            val.name
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


  def tss(nil), do: ""
  def tss(%Time{} = t), do: tss(t |> Time.to_string)
  def tss(st), do: st |> String.slice(0,5)

  def tsss(nil), do: ""
  def tsss(%Time{} = t), do: tsss(t |> Time.to_string)
  def tsss(st), do: st |> String.slice(6..7)

  def tssa(nil), do: ""
  def tssa(%Time{} = t), do: tssa(t |> Time.to_string)
  def tssa(st), do: st |> String.slice(6..6)

  def tssb(nil), do: ""
  def tssb(%Time{} = t), do: tssb(t |> Time.to_string)
  def tssb(st), do: st |> String.slice(7..7)

end
