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
      every: :timer.seconds(2),
      run: fn -> RoomSanctum.Worker.Ankyra.refresh_db_cfg(opts[:id]) end,
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

  #
  def handle_cast(:refresh_db_cfg, state) do
    p = Accounts.get_rabbit_user!(state[:id])
    {:noreply, state |> Map.put(:ankyra, p)}
  end

  def handle_cast({:publish, data}, state) do
#    IO.puts("gottem here")

    case AMQP.Application.get_channel(:default) do
      {:ok, chan} -> AMQP.Basic.publish(chan, "amq.topic", state.ankyra.topic, data |> Poison.encode!)
      {:error, error} -> IO.inspect(error)
    end
    {:noreply, state}
  end
end
