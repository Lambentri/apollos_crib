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

    {:ok, %{id: opts[:id], pythiae: nil, vision: nil}}
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
    if current != state.vision do
      IO.puts("change detected")
      for a <- state.pythiae.ankyra do
        RoomSanctum.Worker.Ankyra.publish(a, current.data |> condense)
      end
    end
    {:noreply, state |> Map.put(:vision, current)}
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
      IO.inspect({id, type, datum})
      {"#{type}-#{id}", RoomSanctum.Condenser.BasicMQTT.condense({id, type}, datum)} end) |> IO.inspect |> Enum.into(%{})
  end


end
