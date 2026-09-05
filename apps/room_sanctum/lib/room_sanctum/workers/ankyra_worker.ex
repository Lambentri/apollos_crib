defmodule RoomSanctum.Worker.Ankyra do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Accounts
  alias RoomSanctum.Configuration

  # Asking is cheap and answering is not: a vision's queries all run again.
  @request_floor_ms 1_000

  # How long a reported position is worth *showing*. Five minutes is a trail
  # rather than a history: long enough to see which way somebody is going,
  # short enough that it is gone before it is a record.
  @positions_shown_s 300

  # How long one is worth *keeping*, which is not the same question. A Plani
  # may wait up to half an hour before it gives up on a client and goes home,
  # and it cannot ask about a position that has already been dropped. Still a
  # trail rather than a record: nothing here outlives the process.
  @positions_ttl_s 1800
  @positions_kept 64

  @registry :zeus
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("ankyra" <> opts[:id]))
  end

  def init(opts) do
    Periodic.start_link(
      # A rabbit user changes about never, and this was re-reading it every two
      # seconds. No broadcast for it: it is written through Accounts rather
      # than Configuration, so it is the one worker still genuinely polling.
      every: :timer.seconds(60),
      run: fn -> RoomSanctum.Worker.Ankyra.refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    # Five seconds rather than two: this is an HTTP call to the management
    # API now, not a local queue declare, and how many phones are attached is
    # not a fast-moving number.
    Periodic.start_link(
      every: :timer.seconds(5),
      run: fn -> RoomSanctum.Worker.Ankyra.meta_check(opts[:id]) end,
      initial_delay: 10
    )

    {:ok,
     %{id: opts[:id], ankyra: nil, requests: nil, last_request: nil, positions: []}}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  # Public
  def refresh_db_cfg(name) do
    "ankyra#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def publish(name, data) do
    "ankyra#{name}"
    |> via_tuple()
    |> GenServer.cast({:publish, data})
  end

  def publish_img(name, data) do
    "ankyra#{name}"
    |> via_tuple()
    |> GenServer.cast({:publish_img, data})
  end

  @doc """
  The Plus board, on a topic of its own.

  Beside `publish/2` rather than replacing it: the two are the same board read
  two ways, and every client that exists reads the Basic one. A second topic
  costs a subscriber that does not want it nothing, where a second shape on the
  same topic would cost it the board.
  """
  def publish_plus(name, data) do
    "ankyra#{name}"
    |> via_tuple()
    |> GenServer.cast({:publish_plus, data})
  end

  @doc """
  Where a client last said it was, or nil.

  A call rather than a broadcast because the asker wants it now and only when
  it is asking: a Plani resolving its anchor on a tick, not a page watching a
  trail. Nil when that client has not reported inside the window, which is the
  signal to fall back to a home foci rather than an error.
  """
  def position(name, client_id, max_age_s \\ @positions_shown_s) do
    try do
      "ankyra#{name}"
      |> via_tuple()
      |> GenServer.call({:position, client_id, max_age_s}, 5_000)
    rescue
      # A registry that is not up raises from the lookup rather than exiting.
      ArgumentError -> nil
    catch
      # A worker that is not up yet, or a node on its way down. Not knowing
      # where somebody is is a normal answer here.
      :exit, _ -> nil
    end
  end

  def meta_check(name) do
    "ankyra#{name}"
    |> via_tuple()
    |> GenServer.cast(:meta_check)
  end

  def topic(id), do: "ankyra:#{id}"

  def handle_call({:position, client_id, max_age_s}, _from, state) do
    latest =
      state.positions
      |> prune(max_age_s)
      |> Enum.find(fn p -> is_nil(client_id) or p.client_id == client_id end)

    {:reply, latest, state}
  end

  def handle_cast(:meta_check, %{ankyra: nil} = state), do: {:noreply, state}

  # Positions age out whether or not anything is arriving, so the pruning
  # rides the check that already runs every couple of seconds. Without it a
  # client that stopped moving would sit on the page indefinitely.
  def handle_cast(:meta_check, %{positions: [_ | _]} = state) do
    pruned = prune(state.positions)

    if pruned != state.positions do
      broadcast_positions(state.id, pruned)
    end

    do_meta_check(%{state | positions: pruned})
  end

  def handle_cast(:meta_check, state), do: do_meta_check(state)

  def handle_cast(:refresh_db_cfg, state) do
    p = Accounts.get_rabbit_user!(state[:id])
    {:noreply, state |> Map.put(:ankyra, p) |> listen_for_requests()}
  end

  def handle_cast({:publish, data}, state) do
    case AMQP.Application.get_channel(:default) do
      {:ok, chan} ->
        AMQP.Basic.publish(chan, "amq.topic", state.ankyra.topic, data |> Poison.encode!())

      {:error, error} ->
        IO.inspect(error)
    end

    {:noreply, state}
  end

  def handle_cast({:publish_plus, data}, state) do
    case AMQP.Application.get_channel(:default) do
      {:ok, chan} ->
        AMQP.Basic.publish(
          chan,
          "amq.topic",
          state.ankyra.topic <> ".plus",
          data |> Poison.encode!()
        )

      {:error, error} ->
        Logger.warning("ankyra #{state.id}: could not publish plus: #{inspect(error)}")
    end

    {:noreply, state}
  end

  def handle_cast({:publish_img, data}, state) do
    IO.puts("and here")

    case AMQP.Application.get_channel(:default) do
      {:ok, chan} ->
        AMQP.Basic.publish(chan, "amq.topic", state.ankyra.topic <> ".img", data |> Poison.encode!()) |> IO.inspect

      {:error, error} ->
        IO.inspect(error)
    end

    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, _meta}, state), do: {:noreply, state}
  def handle_info({:basic_cancel, _meta}, state), do: {:noreply, state |> Map.put(:requests, nil)}
  def handle_info({:basic_cancel_ok, _meta}, state), do: {:noreply, state}

  def handle_info({:basic_deliver, payload, %{routing_key: key}}, state) do
    cond do
      String.contains?(key, ".up.") -> {:noreply, remember_position(state, payload)}
      true -> {:noreply, serve_request(state, key)}
    end
  end

  def handle_info({:status_result, count}, state) do
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      topic(state.id),
      {:ankyra_status, count}
    )

    {:noreply, state}
  end

  @doc """
  Who is attached to this Ankyra, as `%{count: n, client_ids: ids}` -- or nil
  if we could not find out.

  RabbitMQ will not answer this over AMQP. An MQTT subscriber's queue is
  exclusive to the connection that made it, so a passive `queue.declare` from
  ours is refused with `405 RESOURCE_LOCKED`; and since 3.12 a QoS 0
  subscription is a `rabbit_mqtt_qos0_queue`, a pseudo-queue whose stat is the
  constant `{ok, 0, 0}` with no consumer ever counted. Both roads led to zero,
  which is what the detail page reported while two clients sat there happily
  receiving.

  The management API does know. Every connection carries the protocol it
  speaks, the user it authenticated as, and -- for MQTT -- the client id it
  announced. An Ankyra *is* a rabbit user, so MQTT connections under that
  username are exactly its clients, and their ids are the ones the allow-list
  is written in.

  `count` is every matching connection; `client_ids` only those that announced
  one. They are not always the same number, which is why the count is not
  taken from the length of the list: a connection with no client id still has
  someone on the end of it.

  nil rather than zero when the API cannot be reached: "we do not know" and
  "nobody is listening" are different things, and the page draws them
  differently. Reporting the unreachable case as zero is the bug this replaces.
  """
  def connected_clients(username) do
    cfg = Application.get_env(:room_sanctum, :rabbit_mgmt, [])

    with url when is_binary(url) <- cfg[:url],
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- fetch_connections(url, cfg),
         {:ok, connections} when is_list(connections) <- Jason.decode(body) do
      vhost = cfg[:vhost] || "/"
      mine = Enum.filter(connections, &mqtt_connection_for?(&1, username, vhost))

      client_ids =
        mine
        |> Enum.map(&get_in(&1, ["client_properties", "client_id"]))
        |> Enum.filter(&is_binary/1)
        |> Enum.sort()

      %{count: length(mine), client_ids: client_ids}
    else
      other ->
        Logger.debug("ankyra: could not read connections from management API: #{inspect(other)}")
        nil
    end
  end

  # HTTPoison answers with a tuple for anything the far end does, but hackney
  # itself throws -- so a broker that is merely unreachable arrives here as an
  # exception, and unrescued it would kill the spawned checker with no status
  # ever sent and the badge stuck on "checking" forever.
  # Listen for a client asking for something.
  #
  # A Pythiae publishes on change and on its own tick, so a client that has just
  # woken up -- a phone out of a pocket, a panel after a power cut -- can be
  # looking at a board from some time ago with no way to ask for a fresh one.
  # This is the way to ask.
  #
  # The queue is exclusive and auto-deleting: it belongs to this worker and
  # should go when it does, rather than accumulating requests for a process that
  # is not there to serve them.
  defp listen_for_requests(%{requests: tag} = state) when not is_nil(tag), do: state

  defp listen_for_requests(%{ankyra: nil} = state), do: state

  defp listen_for_requests(state) do
    with {:ok, conn} <- AMQP.Application.get_connection(:default),
         {:ok, chan} <- AMQP.Channel.open(conn),
         {:ok, %{queue: queue}} <- AMQP.Queue.declare(chan, "", exclusive: true, auto_delete: true),
         :ok <- AMQP.Queue.bind(chan, queue, "amq.topic", routing_key: request_key(state)),
         :ok <- AMQP.Queue.bind(chan, queue, "amq.topic", routing_key: uplink_key(state)),
         {:ok, tag} <- AMQP.Basic.consume(chan, queue, self(), no_ack: true) do
      Logger.info("ankyra #{state.id} listening for requests on #{request_key(state)}")
      state |> Map.put(:requests, tag) |> Map.put(:requests_chan, chan)
    else
      error ->
        Logger.warning("ankyra #{state.id} could not listen for requests: #{inspect(error)}")
        state
    end
  end

  defp request_key(state), do: state.ankyra.topic <> ".publish.#"

  defp uplink_key(state), do: state.ankyra.topic <> ".up.#"

  # The consumer's own lifecycle. Nothing to do but let them through.

  # Serve a request, if one is due.
  #
  # Debounced: asking is cheap and a vision's queries are not, so a client in a
  # loop would have the server running them as fast as it could. One a second is
  # more than enough to feel immediate, and the Pythiae's own tick covers
  # everything else.
  defp serve_request(state, key) do
    now = DateTime.utc_now()

    if too_soon?(state.last_request, now) do
      state
    else
      for pythiae <- Configuration.list_pythiae(:ankyra, state.id) do
        serve(pythiae, key)
      end

      Map.put(state, :last_request, now)
    end
  end

  # What was asked for, from the end of the routing key. `.img` gets the board
  # drawn; anything else gets the board itself, since that is what a client
  # that has just woken up wants and the reason to guess at all.
  defp serve(pythiae, key) do
    id = to_string(pythiae.id)

    if String.ends_with?(key, ".img") do
      RoomSanctum.Worker.Pythiae.publish_img(id)
    else
      RoomSanctum.Worker.Pythiae.query_current_now(id)
    end
  end

  defp do_meta_check(state) do
    parent = self()
    username = state.ankyra.username

    spawn(fn -> send(parent, {:status_result, connected_clients(username)}) end)

    {:noreply, state}
  end

  # Where a client said it was, kept for as long as it is worth showing.
  #
  # In memory and nowhere else: this is a trail on a page somebody is looking
  # at, not a record of where anybody has been. It goes when the worker does,
  # and each fix goes five minutes after it arrived.
  defp remember_position(state, payload) do
    case decode_position(payload) do
      nil ->
        state

      position ->
        positions = prune([position | state.positions]) |> Enum.take(@positions_kept)
        broadcast_positions(state.id, positions)
        %{state | positions: positions}
    end
  end

  defp decode_position(payload) do
    with {:ok, %{"lat" => lat, "lon" => lon} = fix} <- Poison.decode(payload),
         true <- is_number(lat) and is_number(lon) do
      %{
        lat: lat,
        lon: lon,
        accuracy_m: Map.get(fix, "accuracy_m"),
        speed_mps: Map.get(fix, "speed_mps"),
        client_id: Map.get(fix, "client_id"),
        # When it reached us, not when the phone says it was taken: a clock
        # that is wrong should not put a fix in the future or age it out early.
        at: DateTime.utc_now()
      }
    else
      _ -> nil
    end
  end

  defp prune(positions, max_age_s \\ @positions_ttl_s) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_s, :second)
    Enum.filter(positions, fn p -> DateTime.compare(p.at, cutoff) == :gt end)
  end

  # The page draws a five minute trail whatever the worker is holding for the
  # Plani's benefit -- keeping a position and showing it are different
  # questions, and the answer to the second did not change.
  defp broadcast_positions(id, positions) do
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      topic(id),
      {:ankyra_positions, prune(positions, @positions_shown_s)}
    )
  end

  defp too_soon?(nil, _now), do: false

  defp too_soon?(last, now), do: DateTime.diff(now, last, :millisecond) < @request_floor_ms

  defp fetch_connections(url, cfg) do
    HTTPoison.get(
      String.trim_trailing(url, "/") <> "/api/connections?columns=protocol,user,vhost,client_properties.client_id",
      [{"accept", "application/json"}],
      hackney: [basic_auth: {to_string(cfg[:username]), to_string(cfg[:password])}],
      timeout: 2_000,
      recv_timeout: 2_000
    )
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  # "MQTT 3-1-1" today, "MQTT 5-0" the moment a client asks for it -- the
  # version is not what is being asked about here.
  defp mqtt_connection_for?(
         %{"protocol" => protocol, "user" => user, "vhost" => on_vhost},
         username,
         vhost
       )
       when is_binary(protocol) do
    user == username and on_vhost == vhost and String.starts_with?(protocol, "MQTT")
  end

  defp mqtt_connection_for?(_conn, _username, _vhost), do: false
end
