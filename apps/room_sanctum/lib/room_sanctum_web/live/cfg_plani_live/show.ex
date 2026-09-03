defmodule RoomSanctumWeb.PlaniLive.Show do
  use RoomSanctumWeb, :live_view_a

  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    # The anchor is not broadcast -- it is resolved on the worker's own tick
    # and held there -- so the page asks, rather than waiting to be told.
    if connected?(socket), do: :timer.send_interval(5_000, self(), :look)

    {:ok, socket |> assign(:anchor, nil) |> assign(:state, %{data: %{}, queries: []})}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Plani")
     |> assign(:plani, Configuration.get_plani!(id))
      |> assign(:sources, Configuration.list_cfg_sources({:user, socket.assigns.current_user.id}))
     |> look()}
  end

  @impl true
  def handle_info(:look, socket), do: {:noreply, look(socket)}

  defp look(socket) do
    id = to_string(socket.assigns.plani.id)

    socket
    |> assign(:anchor, RoomSanctum.Worker.Plani.where(id))
    |> assign(:state, RoomSanctum.Worker.Plani.get_state(id))
  end

  @doc """
  Where to centre the map: the anchor, in the shape the map component wants.

  Nil until a worker has resolved one, which the component reads as "fit
  whatever markers there are" -- the right answer for a Plani that has not
  ticked yet.
  """
  def focus(%{anchor: %Geo.Point{coordinates: {lon, lat}}}), do: %{lat: lat, lng: lon}
  def focus(_), do: nil

  @doc """
  The radius, as a ring to draw around the anchor.

  A polyline rather than a circle: the map already draws lines as a child
  element that LiveView adds and removes, and a sixty-four sided ring is a
  circle at any zoom a city is read at. Adding a circle element would mean new
  JavaScript for the same picture.

  Metres to degrees the flat way -- a kilometre is not far enough for the
  curvature to show, and the longitude scale is taken at the ring's own
  latitude so it does not go oval further north.
  """
  def radius_ring(%{anchor: %Geo.Point{coordinates: {lon, lat}}}, radius_m) when is_integer(radius_m) do
    d_lat = radius_m / 111_320
    d_lon = radius_m / (111_320 * max(:math.cos(lat * :math.pi() / 180), 0.01))

    points =
      for step <- 0..64 do
        angle = step / 64 * 2 * :math.pi()
        [lat + d_lat * :math.sin(angle), lon + d_lon * :math.cos(angle)]
      end

    [%{id: "radius", points: points, color: "#38bdf8"}]
  end

  def radius_ring(_where, _radius), do: []

  @doc """
  The things found near the anchor, as map markers.

  Bikes go on their own layer because the component draws them differently;
  everything else is a station, which is the component's generic marker.
  """
  def markers(%{places: places}, kind) when is_list(places) do
    places
    |> Enum.filter(&(marker_layer(&1.kind) == kind))
    |> Enum.map(&as_marker/1)
  end

  def markers(_where, _kind), do: []

  defp marker_layer(:bike), do: :bikes
  defp marker_layer(_kind), do: :stations

  defp as_marker(place) do
    %{
      place: %Geo.Point{coordinates: {place.lon, place.lat}, srid: 4326},
      station_id: "#{place.source_id}-#{place.name}",
      bike_id: "#{place.source_id}-#{place.name}",
      name: place.name,
      short_name: place.name,
      capacity: 0,
      address: place.source_name,
      lat: place.lat,
      lon: place.lon
    }
  end

  @doc "A point as something readable, or nil."
  def coordinates(%{anchor: %Geo.Point{coordinates: {lon, lat}}}) do
    "#{Float.round(lat, 5)}, #{Float.round(lon, 5)}"
  end

  def coordinates(_), do: nil

  @doc """
  Every source this Plani asks, named and tinted alike.

  Resolved the same way the worker resolves it, so the page cannot list one
  set while the worker asks another.
  """
  def asked(plani, sources) do
    ids = RoomSanctum.Configuration.Plani.sources_for(plani, sources)
    Enum.filter(sources, &(&1.id in ids))
  end

  @doc "A source's name, for a page that would otherwise show a number."
  def source_name(sources, id) do
    case Enum.find(sources, &(&1.id == id)) do
      nil -> "source #{id}"
      source -> source.name
    end
  end

  @doc """
  What happened to a source on the last tick.

  A count is the happy answer. The others are worth saying out loud: a Plani
  that shows nothing looks the same whether its sources are empty, ineligible
  or raising, and only one of those is something to wait out.
  """
  def outcome(%{notes: notes}, source_id) when is_map(notes) do
    case Map.get(notes, source_id) do
      {:ok, 0} -> {:empty, "nothing near it"}
      {:ok, n} -> {:ok, n}
      {:error, message} -> {:error, message}
      :not_spatial -> {:skipped, "nothing located in this source"}
      nil -> {:pending, "not asked yet"}
    end
  end

  def outcome(_where, _source_id), do: {:pending, "not asked yet"}

  @doc "How many results a source came back with."
  def count_for(state, source_id) do
    state.data
    |> Enum.find(fn {{id, _type}, _rows} -> id == source_id end)
    |> case do
      {_key, rows} -> length(rows)
      nil -> nil
    end
  end
end
