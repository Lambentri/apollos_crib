defmodule RoomSanctum.Worker.Keryx do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("keryx" <> opts[:id]))
  end

  def init(opts) do
    # Start the item cache
    {:ok, _cache_pid} = RoomSanctum.Worker.KeryxItemCache.start_link(keryx_id: opts[:id])

    Periodic.start_link(
      every: :timer.seconds(4),
      run: fn -> RoomSanctum.Worker.Keryx.refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(30),
      run: fn -> RoomSanctum.Worker.Keryx.query_workers(opts[:id]) end,
      initial_delay: 100
    )

    # Subscribe to control topic after a brief delay to allow keryx config to load
    Process.send_after(self(), :subscribe_control, 5000)

    {:ok, %{id: opts[:id], keryx: nil, keryx_q: [], data: [], query_task: nil}}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  # Public
  def refresh_db_cfg(name) do
    "keryx#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def query_workers(name) do
    "keryx#{name}"
    |> via_tuple()
    |> GenServer.cast(:query_workers)
  end

  def get_state(name) do
    "keryx#{name}"
    |> via_tuple
    |> GenServer.call(:return_state, 15_000)
  end

  #

  def handle_cast(:refresh_db_cfg, state) do
    k = Configuration.get_keryx!(state[:id])
    queries = Configuration.get_queries!(k.query_ids)
    {:noreply, state |> Map.put(:keryx, k) |> Map.put(:keryx_q, queries)}
  end

  def handle_cast(:query_workers, state) do
    # Cancel previous task if still running
    if state.query_task && Process.alive?(state.query_task.pid) do
      Task.shutdown(state.query_task, :brutal_kill)
    end

    # Start async task to query workers
    task =
      Task.async(fn ->
        query_all_workers(state.keryx_q, state.keryx)
      end)

    {:noreply, state |> Map.put(:query_task, task)}
  end

  # Handle async task completion
  def handle_info(:subscribe_control, state) do
    if state.keryx do
      control_topic = "/apollos/keryx/#{state.keryx.name}/control"
      queue_name = "keryx_control_#{state.keryx.id}"

      case AMQP.Application.get_channel(:default) do
        {:ok, chan} ->
          # Declare a queue for this specific keryx instance
          {:ok, %{queue: ^queue_name}} = AMQP.Queue.declare(chan, queue_name, durable: false, auto_delete: true)

          # Bind the queue to the control topic
          :ok = AMQP.Queue.bind(chan, queue_name, "amq.topic", routing_key: control_topic)

          # Subscribe to the queue
          {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue_name)
          Logger.info("Subscribed to control topic: #{control_topic} via queue: #{queue_name}")
        {:error, error} ->
          Logger.error("Failed to subscribe to control topic: #{inspect(error)}")
      end
    end
    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    # AMQP confirmation that subscription was successful
    {:noreply, state}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _tag}}, state) do
    # AMQP notification that subscription was cancelled
    {:noreply, state}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _tag}}, state) do
    # AMQP confirmation that cancellation was successful
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, _meta}, state) do
    # Handle incoming control messages
    case Poison.decode(payload) do
      {:ok, %{"action" => "refresh"}} ->
        Logger.info("Received refresh command for Keryx #{state.id}")
        query_workers(state.id)
        {:noreply, state}

      {:ok, %{"action" => "refresh", "query_id" => query_id}} ->
        Logger.info("Received refresh command for Query #{query_id}")
        refresh_single_query(state, query_id)
        {:noreply, state}

      _ ->
        Logger.warn("Received unknown control message: #{payload}")
        {:noreply, state}
    end
  end

  def handle_info({ref, queried_data}, state) when is_reference(ref) do
    # Task completed successfully
    Process.demonitor(ref, [:flush])
    {:noreply, state |> Map.put(:data, queried_data)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task crashed or was killed, keep previous data
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call(:return_state, _from, state) do
    response = %{
      data: state.data,
      queries: state.keryx_q,
      name: if(state.keryx, do: state.keryx.name, else: "Unknown")
    }
    {:reply, response, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  # Refresh a single query
  defp refresh_single_query(state, query_id) do
    case Enum.find(state.keryx_q, fn q -> q.id == query_id end) do
      nil ->
        Logger.warn("Query #{query_id} not found in Keryx #{state.id}")
      q ->
        Task.start(fn ->
          r = execute_query(q)
          publish_query_data(state.keryx.id, state.keryx.name, q.source.type, q.id, r, q)
        end)
    end
  end

  # Execute a single query
  defp execute_query(q) do
    case q.source.type do
      :gtfs ->
        RoomGtfs.Worker.query_stop(q.source.id, q.query)

      :gbfs ->
        RoomGbfs.Worker.query_stop(q.source.id, q.query)

      :tidal ->
        RoomTidal.Worker.query_tides(q.source.id, q.query)

      :weather ->
        RoomWeather.Worker.query_weather(
          q.source.id,
          q.query
        )

      :aqi ->
        RoomAirQuality.Worker.query_place(
          q.source.id,
          q.query
        )

      :ephem ->
        RoomEphem.Worker.query_ephem(
          q.source.id,
          q.query
        )

      :calendar ->
        RoomCalendar.Worker.query_calendar(
          q.source.id,
          q.query
        )

      :cronos ->
        RoomCronos.Worker.query_cronos(q.id, q.query)

      :gitlab ->
        case RoomGitlab.Worker.pid(q.source.id) do
          nil -> []
          _val -> (Process.alive?(RoomGitlab.Worker.pid(q.source.id)) &&
                     RoomGitlab.Worker.read_jobs(q.source.id, q.query)) || []
        end

      :github ->
        case RoomGithub.Worker.pid(q.source.id) do
          nil ->
            []

          _val ->
            level = Map.get(q.query, :level) || Map.get(q.query, "level") || "runs"

            if Process.alive?(RoomGithub.Worker.pid(q.source.id)) do
              case level do
                "jobs" -> RoomGithub.Worker.read_jobs(q.source.id, q.query)
                _ -> RoomGithub.Worker.read_runs(q.source.id, q.query)
              end
            else
              []
            end
        end

      :packages ->
        RoomPackages.Worker.read(q.source.id, q.query)

      :drought ->
        case RoomDrought.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomDrought.Worker.read(q.source.id, q.query) || []
        end

      :pollen ->
        case RoomPollen.Worker.pid(q.source.id) do
          nil -> []
          _pid -> RoomPollen.Worker.read(q.source.id, q.query) || []
        end
    end
  end

  # Private helper to query all workers and publish to MQTT
  defp query_all_workers(keryx_q, keryx) do
    keryx_q
    |> Enum.map(fn q ->
      r = execute_query(q)

      # Publish to MQTT: full array + individual items
      publish_query_data(keryx.id, keryx.name, q.source.type, q.id, r, q)

      {{q.id, q.source.type}, r}
    end)
    |> Enum.into(%{})
  end

  defp publish_query_data(keryx_id, name, type, query_id, data, query) when is_list(data) do
    base_topic = "/apollos/keryx/#{name}/#{type}/#{query_id}"

    # Cache items for the UI
    RoomSanctum.Worker.KeryxItemCache.add_items(keryx_id, query_id, type, data)

    case AMQP.Application.get_channel(:default) do
      {:ok, chan} ->
        # Publish the full array to the base topic
        AMQP.Basic.publish(chan, "amq.topic", base_topic, data |> Poison.encode!())

        # Publish metadata using condense function
        publish_metadata(chan, base_topic, type, query_id, data, query)

        # For GTFS, group by route and publish hierarchically
        if type == :gtfs do
          publish_gtfs_hierarchical(chan, base_topic, data)
        else
          # Publish each item to its own topic with a stubbified ID
          data
          |> Enum.each(fn item ->
            item_id = extract_item_id(item, type)
            item_topic = "#{base_topic}/#{item_id}"
            AMQP.Basic.publish(chan, "amq.topic", item_topic, item |> Poison.encode!())
          end)
        end

      {:error, error} ->
        Logger.error("Failed to publish to MQTT: #{inspect(error)}")
    end
  end

  defp publish_query_data(_keryx_id, name, type, query_id, data, _query) do
    # Handle non-list data (publish as-is, no caching)
    topic = "/apollos/keryx/#{name}/#{type}/#{query_id}"

    case AMQP.Application.get_channel(:default) do
      {:ok, chan} ->
        AMQP.Basic.publish(chan, "amq.topic", topic, data |> Poison.encode!())

      {:error, error} ->
        Logger.error("Failed to publish to MQTT: #{inspect(error)}")
    end
  end

  # Publish metadata about the query results using BasicMQTT condense
  defp publish_metadata(chan, base_topic, type, query_id, data, query) do
    # Use the existing condense function to get metadata
    metadata = RoomSanctum.Condenser.BasicMQTT.condense({query_id, type}, data, query)

    meta_topic = "#{base_topic}/meta"
    AMQP.Basic.publish(chan, "amq.topic", meta_topic, metadata |> Poison.encode!())
  end

  # Publish GTFS data hierarchically by route and destination
  defp publish_gtfs_hierarchical(chan, base_topic, data) do
    # Group items by route
    data
    |> Enum.group_by(&extract_gtfs_route/1)
    |> Enum.each(fn {route, route_items} ->
      # Publish all items for this route to <base>/<route>
      route_topic = "#{base_topic}/#{route}"
      AMQP.Basic.publish(chan, "amq.topic", route_topic, route_items |> Poison.encode!())

      # Group by destination within this route
      route_items
      |> Enum.group_by(&extract_gtfs_destination/1)
      |> Enum.each(fn {destination, dest_items} ->
        # Publish items for this route+destination to <base>/<route>/<destination>
        dest_topic = "#{base_topic}/#{route}/#{destination}"
        AMQP.Basic.publish(chan, "amq.topic", dest_topic, dest_items |> Poison.encode!())

        # Also publish individual items
        dest_items
        |> Enum.each(fn item ->
          item_id = extract_item_id(item, :gtfs)
          item_topic = "#{base_topic}/#{route}/#{destination}/#{item_id}"
          AMQP.Basic.publish(chan, "amq.topic", item_topic, item |> Poison.encode!())
        end)
      end)
    end)
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
    # Try to get the destination from the route long name or headsign
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
        # Split on common separators and take the first part
        name
        |> String.split(~r/\s*[-–—]\s*/)
        |> List.first()
    end
  end

  # Extract and stubbify an identifier from an item based on its type
  defp extract_item_id(item, type) when is_map(item) do
    # Try to find a suitable ID field based on the data type
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
      :packages ->
        Map.get(item, :tracking_number) || Map.get(item, "tracking_number") || Map.get(item, :id) || Map.get(item, "id")
      _ ->
        # Fallback: try common ID fields
        Map.get(item, :id) || Map.get(item, "id") || Map.get(item, :uid) || Map.get(item, "uid")
    end

    stubbify(id_value)
  end

  defp extract_item_id(_item, _type), do: generate_stub()

  # Convert a value into a URL-safe stub
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

  # Generate a random stub as fallback
  defp generate_stub do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
    |> String.downcase()
    |> String.slice(0..7)
  end
end
