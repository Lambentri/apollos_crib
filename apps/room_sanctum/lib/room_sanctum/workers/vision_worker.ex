defmodule RoomSanctum.Worker.Vision do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("vision" <> opts[:id]))
  end

  def init(opts) do
    {:ok, %{id: opts[:id]}}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  # Public
  def refresh_db_cfg(name) do
    "vision#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def handle_cast(:refresh_db_cfg, state) do
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end
end
