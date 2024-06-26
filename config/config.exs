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
       ],
       pubsub_server: RoomHermesWeb.PubSub,
       live_view: [
         signing_salt: "Vucluw0A"
       ]

config :room_sanctum,
  ecto_repos: [RoomSanctum.Repo]

# Configures the endpoint
config :room_sanctum,
       RoomSanctumWeb.Endpoint,
       url: [
         host: "localhost"
       ],
       render_errors: [
         view: RoomSanctumWeb.ErrorView,
         accepts: ~w(html json),
         layout: false
       ],
       pubsub_server: RoomSanctum.PubSub,
       live_view: [
         signing_salt: "yWOJF4V9"
       ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :room_sanctum, RoomSanctum.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/room_sanctum/assets", __DIR__),
    env: %{
      "NODE_PATH" => Path.expand("../deps", __DIR__)
    }
  ]

config :tailwind,
  version: "3.1.6",
  default: [
    args: ~w(
    --config=tailwind.config.js
    --input=css/app.css
    --output=../priv/static/assets/app.css
  ),
    cd: Path.expand("../apps/room_sanctum/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger,
       :console,
       format: "$time $metadata[$level] $message\n",
       metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
