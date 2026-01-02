defmodule RoomSanctumWeb.PythiaeLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Accounts

  def intersperse([], _), do: []
  def intersperse(_, []), do: []
  def intersperse([x | xs], [y | ys]) do
    [y, x | intersperse(xs, ys)]
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 500)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:pythiae, Configuration.get_pythiae!(id))
     |> assign(:visions, Configuration.list_visions({:user, socket.assigns.current_user.id}))
     |> assign(:foci, Configuration.list_focis({:user, socket.assigns.current_user.id}))
     |> assign(:ankyra, Accounts.list_users_rabbit({:user, socket.assigns.current_user.id}))
     |> assign(:preview, [])
     |> assign(:preview_mode, :basic)}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)

    %{data: data, queries: queries} =
      RoomSanctum.Worker.Vision.get_state(socket.assigns.pythiae.curr_vision)

    shuffled_consts = socket.assigns.pythiae.consts |> Enum.shuffle |> Enum.with_index |> Enum.map(fn {c, i} -> {{c.title, :const}, c} end) |> Map.new

    data = Map.merge(data, shuffled_consts) |> Enum.shuffle

    {:noreply, socket |> assign(:preview, data) |> assign(:queries, queries)}
  end

  @impl true
  def handle_event("toggle-preview-mode", _params, socket) do
    {:noreply, socket |> assign(:preview_mode, do_toggle(socket.assigns.preview_mode))}
  end

  defp do_toggle(state) do
    case state do
      :basic -> :raw
      :raw -> :basic
    end
  end

  defp page_title(:show), do: "Show Pythiae"
  defp page_title(:edit), do: "Edit Pythiae"

  defp condense({id, type}, data) do
    RoomSanctum.Condenser.BasicMQTT.condense_data({id, type}, data)
  end

  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end

  defp sortert(type) do
    case type do
      :alerts -> 0
      :time -> 1
      :pinned -> 2
      :background -> 3
    end
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

  def get_by_id(id, array) do
    case array do
      [] -> id
      _anything -> array |> Enum.filter(fn i -> i.id == id end) |> List.first()
    end
  end

  @impl true
  def handle_event("do-publish", %{"id" => id}, socket) do
    RoomSanctum.Worker.Pythiae.query_current_now(id)
    {:noreply, socket}
  end

  def handle_event("do-publish-img", %{"id" => id}, socket) do
    RoomSanctum.Worker.Pythiae.publish_img(id)
    {:noreply, socket}
  end
end
