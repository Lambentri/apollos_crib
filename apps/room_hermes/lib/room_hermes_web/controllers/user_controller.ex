defmodule RoomHermesWeb.UserController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback RoomHermesWeb.FallbackController

  def create(conn, %{"username" => username, "password" => password}) do
    case Accounts.find_rabbit_user(username, password) do
      nil ->send_resp(conn, :ok, "deny")
      val ->     send_resp(conn, :ok, "allow")
    end
  end
end