defmodule RoomSanctum.Worker.Pythiae do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("pythiae" <> opts[:id]))
  end

  def init(opts) do
    Configuration.subscribe(:pythiae, opts[:id])

    Periodic.start_link(
      # A backstop, not the mechanism: config changes arrive by broadcast the
      # moment they are written. This only catches a write that never went
      # through Configuration -- a migration, or a hand at a psql prompt.
      every: :timer.seconds(60),
      run: fn -> RoomSanctum.Worker.Pythiae.refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomSanctum.Worker.Pythiae.query_current(opts[:id]) end,
      initial_delay: 100
    )

    {:ok, %{id: opts[:id], pythiae: nil, vision: nil, lastpub: DateTime.utc_now()}}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  # Public
  def refresh_db_cfg(name) do
    "pythiae#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def query_current(name) do
    "pythiae#{name}"
    |> via_tuple()
    |> GenServer.cast(:query_current)
  end

  def query_current_now(name) do
    "pythiae#{name}"
    |> via_tuple()
    |> GenServer.cast(:query_current_now)
  end

  def publish_img(name) do
    "pythiae#{name}"
    |> via_tuple()
    |> GenServer.cast(:publish_img)
  end

  #
  def handle_cast(:refresh_db_cfg, state) do
    p = Configuration.get_pythiae!(state[:id])
    {:noreply, state |> Map.put(:pythiae, p)}
  end

  def handle_cast(:query_current, state) do
    current = showing(state.pythiae)

    cfg_ttl =
      case state.pythiae do
        nil ->
          0

        _val ->
          case state.pythiae.tweaks do
            nil -> 0
            val -> state.pythiae.tweaks |> Map.from_struct() |> Map.get(:ttl, 0) || 0
          end
      end

    comparison = DateTime.add(state.lastpub, cfg_ttl, :second)

    if current != state.vision and DateTime.compare(DateTime.utc_now(), comparison) == :gt do
#      IO.puts("change detected")
#      IO.inspect({DateTime.utc_now(), comparison})

      publish_board(state, current)

      {:noreply, state |> Map.put(:vision, current) |> Map.put(:lastpub, DateTime.utc_now())}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:query_current_now, state) do
    current = showing(state.pythiae)

    publish_board(state, current)

    {:noreply, state |> Map.put(:vision, current)}
  end

  def handle_cast(:publish_img, state) do
    current = showing(state.pythiae)

    for a <- state.pythiae.ankyra do
      RoomSanctum.Worker.Ankyra.publish_img(a, current.data |> condense(current.queries))
    end

    {:noreply, state |> Map.put(:vision, current)}
  end

  # Told rather than asked: the same refresh, run when somebody edits the
  # pythiae instead of every two seconds in case they did.
  def handle_info({:cfg_changed, :pythiae, _id}, state) do
    handle_cast(:refresh_db_cfg, state)
  end

  @doc """
  What this Pythiae is showing: a Plani, or a vision.

  Exclusive, and the Plani wins. A Pythiae pointed at a Plani is asking what
  is near its client; reading its vision as well would answer the same
  question from a fixed place and publish both.

  Both workers hand back the same shape, so nothing past this point -- the
  condensers, Ankyra, any client -- can tell which it was.

  Public because the rule has two readers: this worker, which publishes, and
  the config page's preview, which should show what is about to be published
  rather than what would have been.
  """
  def showing(%{curr_plani: plani_id}) when not is_nil(plani_id) do
    RoomSanctum.Worker.Plani.get_state(plani_id)
  end

  def showing(pythiae) do
    RoomSanctum.Worker.Vision.get_state(pythiae.curr_vision)
  end

  # The board, to every Ankyra this Pythiae publishes to.
  #
  # Twice, where the Pythiae asks for it: the Basic reading on the Ankyra's
  # topic and the Plus one on `<topic>.plus`. Both are whole boards -- Plus
  # falls back to Basic's answer for every type it does not write -- so a
  # client reads one or the other and never has to stitch them together.
  #
  # Condensed once for all of them rather than once per Ankyra, which is a
  # vision's worth of work repeated for every client that was listening.
  defp publish_board(state, current) do
    basic = condense(current.data, current.queries)
    plus = if plus?(state.pythiae), do: condense(current.data, current.queries, :plus)

    for a <- state.pythiae.ankyra do
      RoomSanctum.Worker.Ankyra.publish(a, basic)
      if plus, do: RoomSanctum.Worker.Ankyra.publish_plus(a, plus)
    end
  end

  defp plus?(%{plus: true}), do: true
  defp plus?(_), do: false

  defp condense(data, queries, reading \\ :basic) do
    # Create a map of query id to query info for quick lookup
    query_map = queries |> Enum.map(fn q -> {q.id, q} end) |> Enum.into(%{})

    data
    |> Enum.map(fn {{id, type}, datum} ->
      query = Map.get(query_map, id)

      case condense_one({id, type}, datum, query, reading) do
        {:ok, condensed} -> {"#{key_type(type, reading)}-#{id}", condensed}
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  # What the entry is keyed as. The Plus reading of a GTFS query is a different
  # shape from the Basic one and says so in the key, so a payload is
  # self-describing whichever topic it arrived on -- a client is never left
  # inferring the shape from where it came from.
  #
  # Only GTFS: every other type is Basic's answer under Plus too, and giving it
  # a new key would say a difference that is not there.
  defp key_type(:gtfs, :plus), do: "gtfs_plus"
  defp key_type(type, _reading), do: type

  # One entry, or nothing.
  #
  # A board is a dozen unrelated queries, and one of them raising used to take
  # the publish down with it -- so a single dock with an unexpected shape meant
  # no board at all, on every tick, with nothing saying why. The client already
  # drops what it cannot read and draws the rest; this is the same call made at
  # the other end, where there is a log to say it happened.
  defp condense_one({id, type}, datum, query, reading) do
    condenser = condenser(reading)

    condensed =
      if query do
        condenser.condense({id, type}, datum, query)
      else
        condenser.condense_data({id, type}, datum)
      end

    {:ok, condensed}
  rescue
    error ->
      Logger.warning("pythiae: dropping #{type}-#{id}: #{Exception.message(error)}")
      :error
  end

  defp condenser(:plus), do: RoomSanctum.Condenser.PlusMQTT
  defp condenser(_), do: RoomSanctum.Condenser.BasicMQTT
end
