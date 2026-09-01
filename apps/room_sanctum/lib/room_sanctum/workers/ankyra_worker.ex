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

    Periodic.start_link(
      every: :timer.seconds(2),
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

  defp queue_from_client_id(client_id) do
    "mqtt-subscription-#{client_id}qos0"
  end

  def topic(id), do: "ankyra:#{id}"

  def handle_cast(:meta_check, %{ankyra: nil} = state), do: {:noreply, state}

  def handle_cast(:meta_check, state) do
    parent = self()
    client_ids = state.ankyra.client_ids || []

    spawn(fn ->
      count =
        client_ids
        |> Enum.map(&check_consumer_count(queue_from_client_id(&1)))
        |> Enum.sum()

      send(parent, {:status_result, count})
    end)

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

  defp check_consumer_count(queue) do
    with {:ok, conn} <- AMQP.Application.get_connection(:default),
         {:ok, chan} <- AMQP.Channel.open(conn) do
      Process.unlink(chan.pid)

      result =
        try do
          case AMQP.Queue.declare(chan, queue, passive: true) do
            {:ok, %{consumer_count: n}} -> n
            _ -> 0
          end
        catch
          _, _ -> 0
        end

      if Process.alive?(chan.pid) do
        try do
          AMQP.Channel.close(chan)
        catch
          _, _ -> :ok
        end
      end

      result
    else
      _ -> 0
    end
  end
end
