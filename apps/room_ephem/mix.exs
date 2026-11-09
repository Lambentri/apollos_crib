defmodule RoomEphem.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_ephem,
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Poison pins decimal ~> 2.x; see the root mix.exs. Repeated here so the
      # override holds when this app is built or tested on its own.
      {:decimal, "~> 3.2", override: true},
      # wheretz pins httpoison ~> 1.6 for its download_data task; see the root
      # mix.exs. Repeated here for the same reason as decimal.
      {:httpoison, "~> 3.0", override: true},
      {:nebulex, "~> 2.4"},
      # => When using :shards as backend
      {:shards, "~> 1.0"},
      # => When using Caching Annotations
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:parent, "~> 0.12.1"},
      {:solarex, "~> 0.1.1"},
      {:wheretz, "~> 0.1.16"},
      # wheretz (unmaintained) still asks for httpoison ~> 1.6, which holds
      # hackney at 1.x and its advisories. Its one call, in `mix download_data`,
      # works the same on 3.x.
      {:httpoison, "~> 3.0", override: true},
      {:room_sanctum, in_umbrella: true}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
