defmodule RoomPackages.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus
  @dynamic_refresh_seconds 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("packages" <> opts[:name]))
  end

  @impl true
  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(@dynamic_refresh_seconds),
      run: fn -> RoomPackages.Worker.refresh(opts[:name]) end,
      initial_delay: 10
    )

    {:ok, %{id: opts[:name], data: []}}
  end

  # publiq
  def refresh(name) do
    "packages#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh)
  end

  def read(name, query) do
    "packages#{name}"
    |> via_tuple()
    |> GenServer.call({:read, query})
  end

  def handle_cast(:refresh, state) do
    s = Configuration.get_source!(state[:id])
    {:noreply, state |> Map.put(:data, s.meta.tracking)}
  end

  def handle_call({:read, query}, _from, state) do
    {:reply, state.data, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

end
