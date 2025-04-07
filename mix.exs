defmodule ApollosCrib.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        apollos_crib: [
          include_erts: true,
          include_executables_for: [:unix],
          applications: [
            room_sanctum: :permanent,
            room_hermes: :permanent,
            room_zeus: :permanent,
            room_air_quality: :permanent,
            room_calendar: :permanent,
            room_ephem: :permanent,
            room_gbfs: :permanent,
            room_gtfs: :permanent,
            room_hass: :permanent,
            room_rideshare: :permanent,
            room_tidal: :permanent,
            room_weather: :permanent,
            room_cronos: :permanent,
            room_gitlab: :permanent,
            room_packages: :permanent,
            room_scribes: :permanent,
            runtime_tools: :permanent
          ]
        ]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:sentry, "~> 8.0"},
      {:jason, "~> 1.1"},
      {:hackney, "~> 1.8"},
      # if you are using plug_cowboy
      {:plug_cowboy, "~> 2.3"}
    ]
  end
end
