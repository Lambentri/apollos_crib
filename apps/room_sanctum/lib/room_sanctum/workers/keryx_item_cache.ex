defmodule RoomSanctum.Worker.KeryxItemCache do
  @moduledoc """
  GenServer that caches seen items from Keryx workers.
  Stores item IDs and metadata for each query.
  """
  use GenServer
  require Logger

  @registry :zeus

  # Client API

  def start_link(opts) do
    keryx_id = Keyword.fetch!(opts, :keryx_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(keryx_id))
  end

  def add_items(keryx_id, query_id, type, items) when is_list(items) do
    GenServer.cast(via_tuple(keryx_id), {:add_items, query_id, type, items})
  end

  def get_items(keryx_id, query_id) do
    GenServer.call(via_tuple(keryx_id), {:get_items, query_id})
  end

  def get_all_items(keryx_id) do
    GenServer.call(via_tuple(keryx_id), :get_all_items)
  end

  defp via_tuple(keryx_id), do: {:via, Registry, {@registry, "keryx_cache_#{keryx_id}"}}

  # Server callbacks

  @impl true
  def init(_opts) do
    # State structure: %{query_id => %{items: [...], last_updated: timestamp}}
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:add_items, query_id, type, items}, state) do
    item_entries = items
    |> Enum.map(fn item ->
      item_id = extract_item_id(item, type)
      base_entry = %{
        id: item_id,
        data: item,
        type: type,
        first_seen: get_timestamp(state, query_id, item_id),
        last_seen: DateTime.utc_now()
      }

      # Add route and destination for GTFS items
      if type == :gtfs do
        Map.merge(base_entry, %{
          route: extract_gtfs_route(item),
          destination: extract_gtfs_destination(item)
        })
      else
        base_entry
      end
    end)

    query_state = %{
      items: item_entries,
      type: type,
      last_updated: DateTime.utc_now()
    }

    {:noreply, Map.put(state, query_id, query_state)}
  end

  @impl true
  def handle_call({:get_items, query_id}, _from, state) do
    result = Map.get(state, query_id, %{items: [], last_updated: nil})
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_all_items, _from, state) do
    {:reply, state, state}
  end

  # Private helpers

  defp get_timestamp(state, query_id, item_id) do
    case Map.get(state, query_id) do
      nil -> DateTime.utc_now()
      %{items: items} ->
        case Enum.find(items, fn i -> i.id == item_id end) do
          nil -> DateTime.utc_now()
          item -> item.first_seen
        end
    end
  end

  # Extract item ID (duplicated from keryx_worker for independence)
  defp extract_item_id(item, type) when is_map(item) do
    id_value = case type do
      :gtfs ->
        Map.get(item, :trip_id) || Map.get(item, "trip_id")
      :gbfs ->
        # Use the name field for GBFS instead of station_id
        Map.get(item, :name) || Map.get(item, "name") || Map.get(item, :station_id) || Map.get(item, "station_id")
      :weather ->
        Map.get(item, :time) || Map.get(item, "time") || Map.get(item, :dt) || Map.get(item, "dt")
      :tidal ->
        Map.get(item, :t) || Map.get(item, "t") || Map.get(item, :time) || Map.get(item, "time")
      :aqi ->
        Map.get(item, :parameter) || Map.get(item, "parameter")
      :calendar ->
        Map.get(item, :uid) || Map.get(item, "uid") || Map.get(item, :id) || Map.get(item, "id")
      :ephem ->
        Map.get(item, :name) || Map.get(item, "name")
      :cronos ->
        Map.get(item, :id) || Map.get(item, "id") || Map.get(item, :name) || Map.get(item, "name")
      :gitlab ->
        Map.get(item, :id) || Map.get(item, "id")
      :github ->
        Map.get(item, :id) || Map.get(item, "id")
      :drought ->
        Map.get(item, "fips") || Map.get(item, "state") || Map.get(item, "mapDate") || Map.get(item, :mapDate)
      :pollen ->
        case Map.get(item, "date") || Map.get(item, :date) do
          %{"year" => y, "month" => m, "day" => d} -> "#{y}-#{m}-#{d}"
          %{year: y, month: m, day: d} -> "#{y}-#{m}-#{d}"
          other -> inspect(other)
        end
      :packages ->
        Map.get(item, :tracking_number) || Map.get(item, "tracking_number") || Map.get(item, :id) || Map.get(item, "id")
      _ ->
        Map.get(item, :id) || Map.get(item, "id") || Map.get(item, :uid) || Map.get(item, "uid")
    end

    stubbify(id_value)
  end

  defp extract_item_id(_item, _type), do: generate_stub()

  defp stubbify(nil), do: generate_stub()
  defp stubbify(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> generate_stub()
      stub -> stub
    end
  end
  defp stubbify(value) when is_integer(value), do: Integer.to_string(value)
  defp stubbify(value) when is_float(value), do: Float.to_string(value) |> String.replace(".", "-")
  defp stubbify(value), do: inspect(value) |> stubbify()

  defp generate_stub do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
    |> String.downcase()
    |> String.slice(0..7)
  end

  # Extract route from GTFS item
  defp extract_gtfs_route(item) do
    route = get_in(item, [:trip, :route, :route_short_name]) ||
            get_in(item, ["trip", "route", "route_short_name"]) ||
            "unknown"
    stubbify(route)
  end

  # Extract destination from GTFS item
  defp extract_gtfs_destination(item) do
    destination = get_in(item, [:trip, :trip_headsign]) ||
                  get_in(item, ["trip", "trip_headsign"]) ||
                  extract_destination_from_route_name(item) ||
                  get_in(item, [:trip, :direction, :direction]) ||
                  get_in(item, ["trip", "direction", "direction"]) ||
                  "unknown"
    stubbify(destination)
  end

  # Extract destination from route long name (e.g., "Clarendon Hill - Lechmere Station" -> "Clarendon Hill")
  defp extract_destination_from_route_name(item) do
    route_name = get_in(item, [:trip, :route, :route_long_name]) ||
                 get_in(item, ["trip", "route", "route_long_name"])

    case route_name do
      nil -> nil
      name ->
        name
        |> String.split(~r/\s*[-–—]\s*/)
        |> List.first()
    end
  end
end
