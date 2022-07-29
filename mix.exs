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
    []
  end
end
