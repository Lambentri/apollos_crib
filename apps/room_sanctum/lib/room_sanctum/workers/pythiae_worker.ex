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
    Periodic.start_link(
      every: :timer.seconds(2),
      run: fn -> RoomSanctum.Worker.Pythiae.refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomSanctum.Worker.Pythiae.query_current(opts[:id]) end,
      initial_delay: 100
    )

    {:ok, %{id: opts[:id], pythiae: nil, vision: nil, lastpub: DateTime.utc_now}}
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


  #
  def handle_cast(:refresh_db_cfg, state) do
    p = Configuration.get_pythiae!(state[:id])
    {:noreply, state |> Map.put(:pythiae, p)}
  end

  def handle_cast(:query_current, state) do
    current = RoomSanctum.Worker.Vision.get_state(state.pythiae.curr_vision)
    cfg_ttl = case state.pythiae do
      nil -> 0
      _val -> case state.pythiae.tweaks do
        nil -> 0
        val -> state.pythiae.tweaks |> Map.from_struct |> Map.get(:ttl, 0) || 0
      end

    end
    comparison = DateTime.add(state.lastpub, cfg_ttl, :second)
    if current != state.vision and DateTime.compare(DateTime.utc_now, comparison) == :gt do
      IO.puts("change detected")
      IO.inspect({DateTime.utc_now, comparison})
      for a <- state.pythiae.ankyra do
        RoomSanctum.Worker.Ankyra.publish(a, current.data |> condense)
      end
      {:noreply, state |> Map.put(:vision, current) |> Map.put(:lastpub, DateTime.utc_now)}
    else
      {:noreply, state}
    end

  end

  def handle_cast(:query_current_now, state) do
    current = RoomSanctum.Worker.Vision.get_state(state.pythiae.curr_vision)
    for a <- state.pythiae.ankyra do
      RoomSanctum.Worker.Ankyra.publish(a, current.data |> condense)
    end
    {:noreply, state |> Map.put(:vision, current)}
  end

  defp condense(data) do
    data |> Enum.map( fn {{id, type}, datum} ->
#      IO.inspect({id, type, datum})
      {"#{type}-#{id}", RoomSanctum.Condenser.BasicMQTT.condense({id, type}, datum)} end) |> Enum.into(%{})
  end


end
