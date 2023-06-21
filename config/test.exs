import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :room_hermes,
       RoomHermesWeb.Endpoint,
       http: [
         ip: {127, 0, 0, 1},
         port: 4002
       ],
       secret_key_base: "SSZU0T/ISCK0I8eWje32hfMTPurgBdaqWpHrqDeCGVDRCple1Lsib8s5lYZulSaT",
       server: false

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :room_sanctum,
       RoomSanctum.Repo,
       username: "postgres",
       password: "postgres",
       hostname: "localhost",
       database: "room_sanctum_test#{System.get_env("MIX_TEST_PARTITION")}",
       pool: Ecto.Adapters.SQL.Sandbox,
       pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :room_sanctum, RoomSanctumWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "eBKEbEm1z31DOZ/XNT/1Ahzih/b3HckLReQxcXlYS93U5HxZPFA+me9AiwVFvG5t",
  server: false

# In test we don't send emails.
config :room_sanctum, RoomSanctum.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
