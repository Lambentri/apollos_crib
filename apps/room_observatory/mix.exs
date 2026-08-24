defmodule RoomObservatory.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_observatory,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {RoomObservatory.Application, []},
      extra_applications: [:logger]
    ]
  end

  # This app exists for one reason: something has to know about *both* Phoenix
  # apps at once.
  #
  # room_sanctum and room_hermes do not depend on each other and should not
  # start to. But they run in one release, in one BEAM, and a single PromEx
  # module has to name both routers and both repos — so the alternative was
  # making one of them depend on the other purely for metrics, which would be a
  # lie about the architecture that outlives whoever wrote it.
  defp deps do
    [
      {:prom_ex, "~> 1.11.0"},
      # PromEx's own metrics_server is Plug.Cowboy-based. That is the right
      # choice *here* — unlike the Bandit-based apps in this fleet, cowboy is
      # already in this release via Phoenix 1.7 — so it is declared rather than
      # leaned on transitively.
      {:plug_cowboy, "~> 2.5"},
      {:room_sanctum, in_umbrella: true},
      {:room_hermes, in_umbrella: true},
      # For RoomGtfs.FeedHealth. Realtime feed health is the one thing here that
      # no telemetry event reports and no log line can express -- a feed that
      # stopped being polled produces silence, not an error.
      {:room_gtfs, in_umbrella: true}
    ]
  end
end
