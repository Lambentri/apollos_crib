defmodule RoomGtfs.Worker do
  @moduledoc false
  use GenServer

  @registry :gtfs_registry

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:name]))
  end

  def refresh_db_cfg(name) do
    name |> via_tuple() |> GenServer.cast({:refresh_db_cfg})
  end

  def update_static_data(name) do
    name |> via_tuple() |> GenServer.call(:update_static)
  end

  def update_realtime_data(name) do
    name |> via_tuple() |> GenServer.call({:update_realtime})
  end


  def init(opts) do


    {:ok, %{id: opts[:name]}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(:refresh_db_cfg, state) do
    IO.puts("rerere")
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name),
       do: {:via, Registry, {@registry, name}}
end