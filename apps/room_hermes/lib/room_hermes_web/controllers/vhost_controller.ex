defmodule RoomHermesWeb.VHostController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback RoomHermesWeb.FallbackController

  def create(conn, %{"username" => username, "vhost" => vhost, "ip" => ip}) do
    case vhost do
      "/" -> send_resp(conn, :ok, "allow")
      _otherwise -> send_resp(conn, :ok, "deny")
    end
  end
end