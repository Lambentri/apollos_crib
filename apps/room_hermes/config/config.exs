# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :room_hermes,
       ecto_repos: [RoomHermes.Repo]

# Configures the endpoint
config :room_hermes,
       RoomHermesWeb.Endpoint,
       url: [
         host: "localhost"
       ],
       render_errors: [
         view: RoomHermesWeb.ErrorView,
         accepts: ~w(html json),
         layout: false
       ]


# Configures Elixir's Logger
config :logger,
       :console,
       format: "$time $metadata[$level] $message\n",
       metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"