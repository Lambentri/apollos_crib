defmodule RoomHermes.Repo do
  use Ecto.Repo,
    otp_app: :room_hermes,
    adapter: Ecto.Adapters.Postgres
end
