defmodule RoomSanctumWeb.LandingLive.Index do
  use RoomSanctumWeb, :live_view_ca
  use LiveViewNative.LiveView,
      formats: [:jetpack],
      layouts: [
        jetpack: {RoomSanctumWeb.Layouts.JetPack, :app}
      ]

  alias RoomSanctum.Configuration

  @impl true
  def mount(params, _session, socket) do
    vision =
      case params |> Map.get("viz") do
        nil ->
          Configuration.get_landing_vision()

        val ->
          case Configuration.get_vision(val) do
            nil -> Configuration.get_landing_vision()
            val -> val
          end
      end

    if connected?(socket), do: Process.send_after(self(), :update, 100)

    {
      :ok,
      socket
      |> assign(:vision, vision)
      |> assign(:preview, [])
      |> assign(:queries, [])
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Apollo's Crib")
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 10000)

    %{data: data, queries: queries} =
      RoomSanctum.Worker.Vision.get_state(socket.assigns.vision.id)

    {
      :noreply,
      socket
      |> assign(:preview, data)
      |> assign(:queries, queries)
    }
  end

  defp condense({id, type}, data) do
    RoomSanctum.Condenser.BasicMQTT.condense({id, type}, data)
  end

  def preview(condensed, {id, type}) do
    %{data: condensed, id: id, type: type}
  end

  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  defp get_query_data(item, queries, size \\ 8) do
    as_map =
      queries
      |> Enum.map(fn x -> {x.id, x} end)
      |> Enum.into(%{})

    case Map.get(as_map, item) do
      nil ->
        item

      val ->
        case val.name
             |> String.length() > size do
          true ->
            s =
              val.name
              |> String.slice(0, size)

            s <> "..."

          false ->
            val.name
        end
    end
  end
end
