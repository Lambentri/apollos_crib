defmodule RoomGtfs.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_gtfs,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  # `mod:` is set so that RoomGtfs.Application.start/2 runs and registers the
  # GTFS-realtime protobuf extensions. Without a start callback the extension
  # modules compile, sit there, and are never put in the registry the decoder
  # consults -- which fails silently rather than loudly.
  def application do
    [
      extra_applications: [:logger],
      mod: {RoomGtfs.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:csv, "~> 3.0"},
      {:nimble_csv, "~> 1.2"},
      {:postgrex, "~> 0.17", override: true},
#      {:ecto_interval, "~> 0.2.5"},
#      {:ecto_interval, git: "https://github.com/mathiasose/ecto_interval.git"},
      {:httpoison, "~> 1.8"},
      {:protobuf, "~> 0.17.0"},
      {:parent, "~> 0.12.1"},
      {:unzip, "~> 0.8"},
      {:room_sanctum, in_umbrella: true}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
