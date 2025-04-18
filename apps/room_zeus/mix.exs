defmodule RoomZeus.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_zeus,
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
  def application do
    [
      extra_applications: [:logger],
      mod: {RoomZeus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nebulex, "~> 2.4"},
      # => When using :shards as backend
      {:shards, "~> 1.0"},
      # => When using Caching Annotations
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:parent, "~> 0.12.1"},
      {:room_sanctum, in_umbrella: true},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
