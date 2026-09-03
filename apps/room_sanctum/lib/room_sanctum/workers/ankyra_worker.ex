defmodule RoomSanctum.Worker.Ankyra do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Accounts

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

    {:ok, %{id: opts[:id], ankyra: nil}}
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

  def meta_check(name) do
    "ankyra#{name}"
    |> via_tuple()
    |> GenServer.cast(:meta_check)
  end

  def topic(id), do: "ankyra:#{id}"

  def handle_cast(:meta_check, %{ankyra: nil} = state), do: {:noreply, state}

  def handle_cast(:meta_check, state) do
    parent = self()
    username = state.ankyra.username

    spawn(fn -> send(parent, {:status_result, connected_clients(username)}) end)

    {:noreply, state}
  end

  def handle_cast(:refresh_db_cfg, state) do
    p = Accounts.get_rabbit_user!(state[:id])
    {:noreply, state |> Map.put(:ankyra, p)}
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
