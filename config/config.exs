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
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --loader:.css=text),
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
config :room_sanctum, Oban,
       engine: Oban.Engines.Basic,
       # gtfs_import is 1 on purpose. A GTFS static import bulk-loads millions of
       # rows through its own Postgrex connections, and several at once — which
       # is what happened when every source scheduled itself for midnight —
       # buries Postgres. See RoomGtfs.ImportJob. Raising this trades database
       # load for getting through the feeds sooner.
       queues: [default: 10, webhooks: 20, emails: 20, gtfs_import: 1],
       # Nothing rescued a job whose process died. A VM crash mid-import left
       # the row in `executing` for good, and because ImportJob's uniqueness
       # counts `executing` with no expiry, that one row blocked every future
       # import of the feed -- the button on /cfg/offerings/work answered
       # "already outstanding" for ever, and psql was the only way out.
       #
       # rescue_after is the part to get right. Lifeline decides a job is
       # orphaned from how long ago it was attempted, not from whether it is
       # actually running, so a value shorter than a real import starts a
       # second one while the first is midway through truncating the same
       # tables. Measured over fifteen completed imports the worst case was
       # under two minutes and the average was thirty-three seconds; thirty
       # minutes is fifteen times the worst of those, which leaves room for a
       # feed much larger than any loaded so far and for a database having a
       # worse day than that one was.
       #
       # Erring long costs little now that a stuck job can be cleared by hand
       # on the queue page rather than waited out.
       plugins: [{Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}],
       repo: RoomSanctum.Repo
config :messenger, smtp_opts: [[port: 2525]]

config :live_view_native,
  plugins: [
    LiveViewNative.Jetpack
  ]

config :mime, :types, %{
  "text/jetpack" => ["jetpack"],
  "text/swiftui" => [:swiftui]
}

config :live_view_native_stylesheet,
  content: [
    swiftui: [
      "lib/**/*swiftui*"
    ],
    jetpack: [
      "lib/**/*jetpack*"
    ]
  ]

# instructs Phoenix on how to encode a given format
config :phoenix_template, :format_encoders,
  [
    jetpack: Phoenix.HTML.Engine,
    swiftui: Phoenix.HTML.Engine
  ]

# instructs Phoenix on which engine to
# use when compiling `neex` templates
config :phoenix, :template_engines, [
  neex: LiveViewNative.Engine
]

# Prometheus metrics for the whole release — see apps/room_observatory.
#
# `metrics_server` rather than a plug in either endpoint: /metrics on a Phoenix
# router would be reachable through the Ingress, which matches `/` as a prefix.
# PromEx's server is Plug.Cowboy-based, which is the right fit here because
# this release already runs cowboy via Phoenix 1.7 — the Bandit apps in this
# fleet use a second Bandit listener instead, for the same reason in reverse.
#
# `grafana: :disabled` is load-bearing, not boilerplate: PromEx would otherwise
# upload its own dashboards on boot, and this fleet's dashboards are committed
# in deployment/grafana and pushed from there.
config :room_observatory, RoomObservatory.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [
    port: 9568,
    path: "/metrics"
  ]

# Which tile server the Leaflet basemaps draw from. Blank means CARTO's keyless
# greyscale basemaps, the frontend's built-in default; set TILE_URL (and
# friends -- see RoomSanctum.Basemap) in the environment to point the maps at
# your own server instead.
config :room_sanctum, :basemap, []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
