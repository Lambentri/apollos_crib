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
            # Depends on both Phoenix apps, so OTP starts it after them.
            room_observatory: :permanent,
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
            room_github: :permanent,
            room_packages: :permanent,
            room_icarus: :permanent,
            room_treasury: :permanent,
            room_bourse: :permanent,
            room_scribes: :permanent,
            room_pollen: :permanent,
            room_drought: :permanent,
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
      {:sentry, "~> 14.0"},
      {:jason, "~> 1.1"},
      # 4.x for CVE-2026-47071, 47076, 47069 and 47075; 1.x has no fix.
      {:hackney, "~> 4.9"},
      # httpoison 3 is the release on hackney 4. wheretz 0.1.16, its latest,
      # still pins ~> 1.6, but only its download_data Mix task makes a request
      # -- a plain get! following redirects, which 3 answers the same way.
      {:httpoison, "~> 3.0", override: true},
      # Poison (even 6.0) still asks for ~> 2.x; it only calls to_string/1 and
      # builds %Decimal{} structs, both unchanged in 3. 3.1.2 is the first with
      # the fixes for CVE-2026-32686 and CVE-2026-97853, and 3's parse limits
      # are what keep a hostile GBFS feed's "1e999999999" out of Ecto casts.
      {:decimal, "~> 3.2", override: true},
      # if you are using plug_cowboy
      {:plug_cowboy, "~> 2.3"}
    ]
  end
end
