defmodule RoomSanctumWeb.SourceLive.LiveLayers do
  @moduledoc """
  What a source has moving right now: vehicles, loose bikes, aircraft.

  The companion to `RoomSanctumWeb.SourceLive.Stations`, which answers the same
  question about places that do not move. Both exist because the tint map draws
  many sources at once and needs one shape per layer regardless of what kind of
  source produced it.

  Every read here goes through a worker rather than the database, and a worker
  may not be running -- a source added a minute ago, one whose supervisor is
  restarting, an app absent from this environment. All of those come back as an
  empty layer, because a map missing its buses is worth more than a page that
  will not render.

  `SourceLive.Show` gathers the same three things its own way, driven by PubSub
  for one source at a time. That is a better fit for a page watching a single
  feed, and merging the two is not obviously an improvement; what would be
  worth sharing is this module's habit of never letting a dead worker through.
  """

  alias RoomSanctum.Storage

  @doc """
  Everything live for one source, as `%{vehicles:, free_bikes:, aircraft:,
  route_types:}`.

  `route_types` comes back alongside the vehicles because a vehicle position
  names a route and the glyph is chosen from the route's type, so the caller
  would otherwise have to know to look it up separately.
  """
  def for_source(%{type: :gtfs, id: id}) do
    vehicles =
      safely(fn -> RoomGtfs.Worker.get_current_vehicle_positions(id) end, [])
      |> Storage.with_trip_context(id)

    %{
      vehicles: vehicles,
      free_bikes: [],
      aircraft: [],
      # Only worth the query if something is actually being drawn.
      route_types: if(vehicles == [], do: %{}, else: Storage.route_types(id))
    }
  end

  def for_source(%{type: :gbfs, id: id}) do
    bikes =
      safely(fn -> Storage.list_gbfs_free_bike_status() end, [])
      |> Enum.filter(&(&1.source_id == id))

    %{vehicles: [], free_bikes: bikes, aircraft: [], route_types: %{}}
  end

  def for_source(%{type: :icarus, id: id}) do
    %{vehicles: [], free_bikes: [], aircraft: aircraft(id), route_types: %{}}
  end

  def for_source(_source), do: empty()

  @doc "Merged layers across several sources, ready to hand to the map."
  def for_sources(sources) do
    sources
    |> Enum.map(&for_source/1)
    |> Enum.reduce(empty(), fn layer, acc ->
      %{
        vehicles: acc.vehicles ++ layer.vehicles,
        free_bikes: acc.free_bikes ++ layer.free_bikes,
        aircraft: acc.aircraft ++ layer.aircraft,
        # Route ids are namespaced per source in the static feed, so a plain
        # merge is safe: two agencies both having a route "1" would collide, but
        # route_types is keyed on the id the vehicle reports and both agencies'
        # vehicles report their own.
        route_types: Map.merge(acc.route_types, layer.route_types)
      }
    end)
  end

  @doc "Whether a source can contribute a live layer at all."
  def live?(%{type: type}), do: type in [:gtfs, :gbfs, :icarus]
  def live?(_source), do: false

  defp empty, do: %{vehicles: [], free_bikes: [], aircraft: [], route_types: %{}}

  # room_icarus is not a declared dependency of room_sanctum -- the umbrella
  # loads it at runtime, but it is absent from this app's test env, and an
  # unloaded module raises rather than exits.
  defp aircraft(id) do
    if Code.ensure_loaded?(RoomIcarus.Worker) do
      safely(fn -> RoomIcarus.Worker.current_aircraft(id) end, [])
    else
      []
    end
  end

  defp safely(fun, default) do
    fun.()
  rescue
    _error -> default
  catch
    :exit, _reason -> default
  end
end
