defmodule RoomScribe.Worker do
  @moduledoc false
  use GenServer
  use Nebulex.Caching
  use AMQP


  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @queue_repub "apollos-returns"
  @repub_error "#{@queue_repub}_error"
  @exchange "lambentri.browser_ctl"
  @queue_snap "lambentri.browser_ctl.snap"


  def start_link(opts) do
    Parent.GenServer.start_link(__MODULE__, opts, name: via_tuple("scribe"))
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def init(opts) do
    {:ok, chan} = AMQP.Application.get_channel(:default)
    setup_queue(chan)

    # Limit unacknowledged messages to 10
    :ok = Basic.qos(chan, prefetch_count: 1)
    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(chan, @queue_repub)
    {:ok, %{name: opts[:name], chan: chan}}
  end

  def request(scribe_id) do
    via_tuple("scribe")
    |> GenServer.cast({:request, scribe_id})
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, state) do
    # You might want to run payload consumption in separate Tasks in production
    consume(state.chan, tag, redelivered, payload)
    {:noreply, state}
  end

  def handle_cast({:request, scribe_id}, state) do
    sc = Configuration.get_scribus!(scribe_id)
    path = System.get_env("PHX_HOST") # todo move to runtime.exs
    full_path = case sc.theme do
      :inky -> "#{path}/p/s/i/#{scribe_id}"
      :color -> "#{path}/p/s/c/#{scribe_id}"
      :her -> "#{path}/p/s/h/#{scribe_id}"
      :afterdark -> "#{path}/p/s/a/#{scribe_id}"
      _ -> "#{path}/p/s/c/#{scribe_id}"
    end

    chan = state.chan

    msg = %{
      url: full_path,
      id: scribe_id,
      resolution: sc.resolution,
      repub_queue: @queue_repub,
      repub_route: @queue_repub,
      outputs: sc.color,
      wait: sc.wait
    }

    AMQP.Basic.publish(chan, @exchange, sc.resolution, msg |> Poison.encode!())

    {:noreply, state}
  end

  defp setup_queue(chan) do
    {:ok, _} = Queue.declare(chan, @repub_error, durable: true)
    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} = Queue.declare(chan, @queue_repub,
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, @repub_error}
      ]
    )
    :ok = Exchange.direct(chan, @exchange, durable: false)
    :ok = Queue.bind(chan, @queue_repub, @exchange, [routing_key: @queue_repub])
  end

  defp consume(channel, tag, redelivered, payload) do
    decoded = payload |> Poison.decode!(keys: :atoms)
    :ok = Basic.ack channel, tag
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "scribus:#{decoded.id}", {:update, decoded})
    write_cache(decoded.id, decoded)
  end

  @decorate cache_put(cache: RoomZeus.Cache, key: {"scribus", id})
  defp write_cache(id, entry) do
    entry
  end

  def read_cache(id)  when is_integer(id), do: read_cache(id |> Integer.to_string)
  def read_cache(id) do
    RoomZeus.Cache.get({"scribus", id})
  end
end
