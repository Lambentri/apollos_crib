defmodule RoomGtfs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @registry :gtfs_registry

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: RoomGtfs.Worker.start_link(arg)
      # {RoomGtfs.Worker, arg}
#      RoomSanctum.Repo,
      {RoomGtfs.DynSupervisor, strategy: :one_for_one},
      {Registry, [keys: :unique, name: @registry]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RoomGtfs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
