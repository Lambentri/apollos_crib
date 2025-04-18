import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :room_sanctum, RoomSanctumWeb.Endpoint, server: true
  config :room_hermes, RoomHermesWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :room_hermes, RoomHermesWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :room_hermes, RoomHermes.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :room_sanctum,
         RoomSanctum.Repo,
         # ssl: true,
         url: database_url,
         pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
         socket_options: maybe_ipv6,
         types: RoomSanctum.PostgresTypes

  config :room_hermes,
         RoomHermes.Repo,
         # ssl: true,
         url: database_url,
         pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
         socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  sport = String.to_integer(System.get_env("SPORT") || "4000")
  hport = String.to_integer(System.get_env("HPORT") || "4001")

  config :room_sanctum,
         RoomSanctumWeb.Endpoint,
         url: [
           host: host,
           port: 443
         ],
         http: [
           # Enable IPv6 and bind on all interfaces.
           # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
           # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
           # for details about using IPv6 vs IPv4 and loopback vs public addresses.
           ip: {0, 0, 0, 0, 0, 0, 0, 0},
           port: sport
         ],
         secret_key_base: secret_key_base

  config :room_hermes,
         RoomHermesWeb.Endpoint,
         url: [
           host: host,
           port: 444
         ],
         http: [
           # Enable IPv6 and bind on all interfaces.
           # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
           # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
           # for details about using IPv6 vs IPv4 and loopback vs public addresses.
           ip: {0, 0, 0, 0, 0, 0, 0, 0},
           port: hport
         ],
         secret_key_base: secret_key_base

  config :amqp,
    connections: [
      default: [url: System.get_env("RABBIT_URL")]
    ],
    channels: [
      default: [connection: :default]
    ]

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :room_sanctum, RoomSanctumWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :room_sanctum, RoomSanctum.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: :prod,
    enable_source_code_context: true,
    root_source_code_paths: [
      "#{File.cwd!()}/apps/room_air_quality",
      "#{File.cwd!()}/apps/room_calendar",
      "#{File.cwd!()}/apps/room_cronos",
      "#{File.cwd!()}/apps/room_ephem",
      "#{File.cwd!()}/apps/room_gbfs",
      "#{File.cwd!()}/apps/room_gtfs",
      "#{File.cwd!()}/apps/room_hass",
      "#{File.cwd!()}/apps/room_hermes",
      "#{File.cwd!()}/apps/room_rideshare",
      "#{File.cwd!()}/apps/room_sanctum",
      "#{File.cwd!()}/apps/room_tidal",
      "#{File.cwd!()}/apps/room_weather",
      "#{File.cwd!()}/apps/room_zeus",
      "#{File.cwd!()}/apps/room_gitlab",
      "#{File.cwd!()}/apps/room_scribe",
      "#{File.cwd!()}/apps/room_packages"
    ],
    tags: %{
      env: "production"
    },
    included_environments: [:prod]

  else

end

config :room_sanctum,
       env: config_env(),
       host: System.get_env("PHX_HOST", "localhost")

