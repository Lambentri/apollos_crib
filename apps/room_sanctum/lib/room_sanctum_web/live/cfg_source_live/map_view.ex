defmodule RoomSanctumWeb.SourceLive.MapView do
  @moduledoc """
  Every source of one tint, on one map: `/cfg/offerings/map/orange`.

  The offerings index already treats tint as a grouping -- the coloured dots
  filter the table by it -- and this is that grouping taken to the map. Tint is
  the only handle the app gives you for "these sources belong together", so it
  is the one thing worth having a map of.

  ## Named `MapView`, not `Map`

  `RoomSanctumWeb.SourceLive.Map` would be the obvious name and is a trap: an
  alias of `Map` shadows `Elixir.Map` inside the module, so `Map.get/2` in this
  file or any file aliasing it would resolve here instead. The map component
  calls `Map.get` on every marker.

  ## Sources that draw nothing

  Only GTFS, GBFS and AirNow sources store geography; see
  `RoomSanctumWeb.SourceLive.Stations`. A tint applied only to, say, weather
  and package sources has nothing to plot, so the page says which sources it
  matched and which of them had places, rather than showing an empty map and
  leaving the reason to be guessed at.
  """

  use RoomSanctumWeb, :live_view_a
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Configuration
  alias RoomSanctumWeb.SourceLive.Stations

  # A backstop, not a budget. An offering's own map draws MBTA's ten thousand
  # stops with no cap at all, and orange alone is three bus agencies and some
  # twenty-three thousand -- so a ceiling low enough to bite on a real tint
  # would be degrading the thing this page exists to do. Canvas circle markers
  # share one renderer and cope with that; this is here so a tint that grows
  # to something absurd fails as a truncated map, which the component says out
  # loud, rather than as a wedged browser.
  @max_markers 50_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tint, nil)
     |> assign(:sources, [])
     |> assign(:stations, [])
     |> assign(:station_statuses, [])
     |> assign(:counts, %{})
     |> assign(:max_markers, @max_markers)}
  end

  @impl true
  def handle_params(%{"tint" => tint}, _url, socket) do
    if RoomSanctum.Tints.valid?(tint) do
      {:noreply, load_tint(socket, tint)}
    else
      # An unknown tint has no stylesheet behind it, so every `bg-#{tint}-500`
      # on the page would render unstyled. Refuse it at the door.
      {:noreply,
       socket
       |> put_flash(:error, "No such tint: #{tint}")
       |> push_navigate(to: ~p"/cfg/offerings")}
    end
  end

  defp load_tint(socket, tint) do
    sources =
      Configuration.list_cfg_sources({:user, socket.assigns.current_user.id})
      |> Enum.filter(&(&1.meta && &1.meta.tint == tint))
      |> Enum.sort_by(& &1.name)

    # Loaded once per source and kept alongside it. The sidebar wants a count
    # per source and the map wants one flat list; deriving both from the same
    # pass is the difference between reading every stops table once and reading
    # it twice.
    #
    # Labelled per source too, because one map holding several of them
    # otherwise gives no way to tell whose stop a marker is.
    per_source =
      Enum.map(sources, fn source ->
        {source, source |> Stations.for_source() |> Stations.label_with_source(source)}
      end)

    socket
    |> assign(:page_title, "#{String.capitalize(tint)} Offerings Map")
    |> assign(:tint, tint)
    |> assign(:sources, sources)
    |> assign(:stations, Enum.flat_map(per_source, fn {_source, stations} -> stations end))
    |> assign(:counts, Map.new(per_source, fn {source, stations} -> {source.id, length(stations)} end))
    |> assign(:station_statuses, Enum.flat_map(sources, &Stations.statuses_for_source/1))
  end

  defp mappable?(source), do: Stations.mappable?(source)

  defp icon_code(source_type), do: RoomSanctumWeb.IconHelpers.icon_code(source_type)
end
