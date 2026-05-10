defmodule RoomGithub.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_github,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nebulex, "~> 2.6"},
      {:shards, "~> 1.1"},
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:httpoison, "~> 1.8"}
    ]
  end
end
