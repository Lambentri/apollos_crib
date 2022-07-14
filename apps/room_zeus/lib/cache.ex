defmodule RoomZeus.Cache do
  use Nebulex.Cache,
    otp_app: :room_zeus,
    adapter: Nebulex.Adapters.Local
end
