defmodule RoomScribes.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_scribes,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 4.1"},
      {:rabbit_common, "~> 4.0"},
      {:nebulex, "~> 2.4"},
      # => When using :shards as backend
      {:shards, "~> 1.0"},
      # => When using Caching Annotations
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:elixir_make, "~> 0.9", override: true },
      {:pixels, "~> 0.3.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
