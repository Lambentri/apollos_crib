defmodule RoomHermesWeb.UserController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback RoomHermesWeb.FallbackController

  def create(conn, %{"username" => username, "password" => password, "client_id" => client_id}) do
    case client_id == username do
      true ->
        case Accounts.find_rabbit_user(username, password) |> IO.inspect do
          nil -> send_resp(conn, :ok, "deny")
          val -> send_resp(conn, :ok, "allow")
        end

      false ->
        send_resp(conn, :ok, "deny")
    end
  end
end
