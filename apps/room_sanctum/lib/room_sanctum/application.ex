defmodule RoomSanctum.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      RoomSanctum.Repo,
      # Start the Telemetry supervisor
      RoomSanctumWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: RoomSanctum.PubSub},
      # Start the Endpoint (http/https)
      RoomSanctumWeb.Endpoint,
      # Start a worker by calling: RoomSanctum.Worker.start_link(arg)
      # {RoomSanctum.Worker, arg}
      {Oban, Application.fetch_env!(:room_sanctum, Oban)},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RoomSanctum.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RoomSanctumWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
