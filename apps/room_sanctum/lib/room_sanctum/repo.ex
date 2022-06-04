defmodule RoomSanctum.Repo do
  use Ecto.Repo,
    otp_app: :room_sanctum,
    adapter: Ecto.Adapters.Postgres
end
