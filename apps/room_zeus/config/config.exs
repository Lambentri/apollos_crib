config :room_zeus, RoomZeus.Cache,
  # => 1 day
  gc_interval: 86_400_000,
  backend: :shards
