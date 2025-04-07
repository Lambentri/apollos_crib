defmodule RoomSanctum.MixProject do
  use Mix.Project

  def project do
    [
      app: :room_sanctum,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {RoomSanctum.Application, []},
      extra_applications: [:logger, :runtime_tools, :amqp]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.2"},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_interval, git: "git@github.com:gmorell/ecto_interval.git"},
#      {:ecto_interval, "~> 0.2"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0", override: true},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 1.0.0-rc.6", override: true},
      {:phoenix_html_helpers, "~> 1.0"},
#      {:live_view_native, "~> 0.3.0"},
      {:live_view_native_jetpack,
       git: "git@github.com:liveview-native/liveview-client-jetpack.git"},
#      {:live_view_native_live_form, "~> 0.3.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:timex, "~> 3.7.8"},
      {:poison, "~> 5.0", override: true},
      {:parent, "~> 0.12.1"},

      # tz provider, less shitty than tzworld, still shitty for diff reasons
      {:wheretz, "~> 0.1.16"},
      {:tzdata, "~> 1.1"},

      # makes the configs go Vroom
      {:polymorphic_embed, "~> 5.0.0", override: true},

      # for the foci
      {:geo_postgis, "~> 3.4"},

      # for Hermes
      {:friendlyid, "~> 0.2.0"},

      # UI
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:mdex, "~> 0.1"},
      {:doggo, "~> 0.8.2"},

      # kube
      {:healthchex, "~> 0.2"},

      # hermes
      #      {:room_hermes, in_umbrella: true}
      {:amqp, "~> 3.3"},
      {:sentry, "~> 8.0"},

      # Q's and other misc
      {:oban, "~> 2.17"},
      {:iconv, "~> 1.0"},
      {:oban_live_dashboard, "~> 0.1.0"},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
