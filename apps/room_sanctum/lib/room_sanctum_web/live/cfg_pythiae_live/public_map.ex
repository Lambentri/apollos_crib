defmodule RoomSanctumWeb.PythiaeLive.PublicMap do
  @moduledoc """
  A pythiae's current vision as a map, for a screen with nothing else on it.

  The same data as `/p/p/:name` and the same refresh; what differs is that this
  draws each query where it *is* and what it currently sees -- arrivals,
  aircraft, bikes, air-quality sites -- rather than listing them as cards. A
  vision whose queries are all in one neighbourhood is a different thing to
  look at on a map than in a column.
  """
  use RoomSanctumWeb, :live_view_ca

  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Configuration
  alias RoomSanctumWeb.Live.Helpers.MapData

  @refresh_ms 15_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 500)

    # No :live layout. Every other page in this app is wrapped in
    # `<main class="container mx-auto">`, and Tailwind's `container` is a
    # max-width -- which boxed the map into a centred column with the window
    # showing either side of it. A page that is only a map wants the window.
    {:ok,
     socket
     |> assign(:queries, [])
     |> assign(:aircraft, [])
     |> assign(:stations, [])
     |> assign(:station_statuses, [])
     |> assign(:free_bikes, [])
     |> assign(:vehicle_positions, [])
     |> assign(:queried_station_ids, [])
     |> assign(:query_summaries, %{})
     |> assign(:curr_vision, "Pending"), layout: false}
  end

  @impl true
  def handle_params(%{"name" => name}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, name)
     |> assign(:pythiae, pythiae_named(name))}
  end

  # get_pythiae!/2 hands back nil for a name nobody has, bang or no bang, and a
  # nil here reaches the template as `@pythiae.name` -- a 500 for what is only
  # a wrong address. This is a public URL: someone will mistype it.
  defp pythiae_named(name) do
    case Configuration.get_pythiae!(:name, name) do
      nil -> raise Ecto.NoResultsError, queryable: RoomSanctum.Configuration.Pythiae
      pythiae -> pythiae
    end
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @refresh_ms)

    %{data: data, queries: queries, name: name} =
      RoomSanctum.Worker.Vision.get_state(socket.assigns.pythiae.curr_vision)

    {:noreply,
     socket
     |> assign(:queries, queries)
     |> assign(:curr_vision, name)
     |> assign_map_layers(data, queries)}
  end

  # As the vision's own map view does it, from the same helpers: a query marker
  # says where a query is, and these say what it currently sees. Computed with
  # the data they belong to so the two are never a tick apart.
  defp assign_map_layers(socket, data, queries) do
    aqi_stations =
      queries
      |> Enum.filter(&(&1.source.type == :aqi))
      |> Enum.map(&MapData.aqi_stations/1)

    docks = MapData.stations(data)

    socket
    |> assign(:aircraft, MapData.aircraft(data))
    |> assign(:free_bikes, MapData.free_bikes(data))
    |> assign(:query_summaries, MapData.summaries(data))
    |> assign(:station_statuses, docks)
    |> assign(:stations, (aqi_stations |> List.flatten() |> MapData.as_stations()) ++ docks)
    |> assign(
      :queried_station_ids,
      aqi_stations |> Enum.map(&List.first/1) |> Enum.reject(&is_nil/1) |> Enum.map(& &1.aqsid)
    )
    |> assign(:vehicle_positions, Enum.flat_map(queries, &MapData.vehicle_positions/1))
  end
end
