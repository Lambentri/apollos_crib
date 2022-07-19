import Config

# Configure your database
config :room_hermes,
       RoomHermes.Repo,
       username: "postgres",
       password: "postgres",
       hostname: "localhost",
       database: "room_sanctum_dev",
       show_sensitive_data_on_connection_error: true,
       pool_size: 10

config :room_hermes,
       RoomHermesWeb.Endpoint,
       # Binding to loopback ipv4 address prevents access from other machines.
       # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
       http: [
              ip: {0, 0, 0, 0},
              port: 4001
       ],
       check_origin: false,
       code_reloader: true,
       debug_errors: true,
       secret_key_base: "KLXXutULmhGl2AX+2voy6oG5N8P39B3dYNd8pjm5MPZ+Tmf7kads7puDprxwqytm"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
