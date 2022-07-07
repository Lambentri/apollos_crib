defmodule RoomZeus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @registry :zeus

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: RoomGtfs.Worker.start_link(arg)
      # {RoomGtfs.Worker, arg}
      #      RoomSanctum.Repo,
      {RoomZeus.DynSupervisor, strategy: :one_for_one, subtype: :gtfs, name: :gtfs},
#      Supervisor.child_spec({RoomZeus.DynSupervisor, strategy: :one_for_one, subtype: :gbfs, name: :gbfs}, id: :zgbfs),
      {Registry, [keys: :unique, name: @registry]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RoomZeus.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
