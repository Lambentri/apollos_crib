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
  alias RoomSanctumWeb.SourceLive.LiveLayers
  alias RoomSanctumWeb.SourceLive.Stations

  # A backstop, not a budget. An offering's own map draws MBTA's ten thousand
  # stops with no cap at all, and orange alone is three bus agencies and some
  # twenty-three thousand -- so a ceiling low enough to bite on a real tint
  # would be degrading the thing this page exists to do. Canvas circle markers
  # share one renderer and cope with that; this is here so a tint that grows
  # to something absurd fails as a truncated map, which the component says out
  # loud, rather than as a wedged browser.
  @max_markers 50_000

  # Matches the source page. The realtime workers poll every 30s, so asking more
  # often than that returns the same feed.
  @refresh :timer.seconds(30)

  # Marker shape is what separates one offering from another here: fill colour
  # already means "what kind of thing this is" and the outline already means
  # "which tint", so shape is the axis left over. Assigned in the order sources
  # are listed, and repeating past the end of this list -- which the legend makes
  # visible, since it shows each source's shape next to its name.
  @shapes ~w(circle square diamond triangle hexagon)

  @impl true
  def mount(_params, _session, socket) do
    # Only once connected: the static render would pay for every worker read and
    # then be replaced.
    if connected?(socket), do: Process.send_after(self(), :refresh_live, 100)

    {:ok,
     socket
     |> assign(:tint, nil)
     |> assign(:sources, [])
     |> assign(:stations, [])
     |> assign(:station_statuses, [])
     |> assign(:counts, %{})
     |> assign(:shapes, %{})
     |> assign(:hidden, MapSet.new())
     |> assign(:max_markers, @max_markers)
     |> assign(:show_aircraft, false)
     |> assign_live(%{vehicles: [], free_bikes: [], aircraft: [], route_types: %{}})}
  end

  @impl true
  def handle_info(:refresh_live, socket) do
    Process.send_after(self(), :refresh_live, @refresh)
    {:noreply,
     assign_live(socket, LiveLayers.for_sources(socket.assigns.sources, socket.assigns.shapes))}
  end

  @impl true
  def handle_event("toggle-aircraft", _params, socket) do
    {:noreply, assign(socket, :show_aircraft, not socket.assigns.show_aircraft)}
  end

  # Hiding is held here rather than pushed at the map, because the markers a
  # hidden source contributes should not be rendered at all -- a tint covering
  # three bus agencies is twenty thousand markers, and turning one off should
  # make the page lighter, not just quieter.
  @impl true
  def handle_event("toggle-source", %{"id" => id}, socket) do
    id = String.to_integer(id)

    hidden =
      if MapSet.member?(socket.assigns.hidden, id) do
        MapSet.delete(socket.assigns.hidden, id)
      else
        MapSet.put(socket.assigns.hidden, id)
      end

    {:noreply, assign(socket, :hidden, hidden)}
  end

  @impl true
  def handle_event("show-all-sources", _params, socket) do
    {:noreply, assign(socket, :hidden, MapSet.new())}
  end

  defp assign_live(socket, layers) do
    socket
    |> assign(:vehicles, layers.vehicles)
    |> assign(:free_bikes, layers.free_bikes)
    |> assign(:aircraft, layers.aircraft)
    |> assign(:route_types, layers.route_types)
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
    shapes =
      sources
      |> Enum.with_index()
      |> Map.new(fn {source, i} -> {source.id, Enum.at(@shapes, rem(i, length(@shapes)))} end)

    per_source =
      Enum.map(sources, fn source ->
        {source, Stations.attach_source(Stations.for_source(source), source, shapes[source.id])}
      end)

    socket
    |> assign(:page_title, "#{String.capitalize(tint)} Offerings Map")
    |> assign(:tint, tint)
    |> assign(:sources, sources)
    |> assign(:shapes, shapes)
    # A tint change is a different set of offerings, so nothing stays hidden
    # across one -- an id hidden here would silently hide an unrelated source.
    |> assign(:hidden, MapSet.new())
    |> assign(:stations, Enum.flat_map(per_source, fn {_source, stations} -> stations end))
    |> assign(:counts, Map.new(per_source, fn {source, stations} -> {source.id, length(stations)} end))
    |> assign(:station_statuses, Enum.flat_map(sources, &Stations.statuses_for_source/1))
    |> then(fn s ->
      # The sources just changed, so anything live already assigned describes the
      # tint that was on screen a moment ago.
      if connected?(s), do: assign_live(s, LiveLayers.for_sources(sources, shapes)), else: s
    end)
  end

  # Filtered at render rather than by reloading: the station lists are the
  # expensive part and do not change when a layer is switched off.
  defp visible(items, hidden, key \\ :source_id) do
    if MapSet.size(hidden) == 0 do
      items
    else
      Enum.reject(items, fn item -> Map.get(item, key) in hidden end)
    end
  end

  defp hidden?(hidden, source), do: MapSet.member?(hidden, source.id)

  defp any_aircraft?(sources), do: Enum.any?(sources, &(&1.type == :icarus))

  # Subway trains report a station rather than a coordinate, so they are drawn at
  # the stop they name. Saying how many is the difference between a map that is
  # slightly approximate and one that is quietly lying.
  defp inferred_note(vehicles) do
    case Enum.count(vehicles, &Map.get(&1, :position_inferred)) do
      0 -> ""
      n -> " (#{n} placed at a stop)"
    end
  end

  defp mappable?(source), do: Stations.mappable?(source)

  defp icon_code(source_type), do: RoomSanctumWeb.IconHelpers.icon_code(source_type)
end
