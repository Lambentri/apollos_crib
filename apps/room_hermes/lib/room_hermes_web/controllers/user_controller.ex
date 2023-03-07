defmodule RoomHermesWeb.UserController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback RoomHermesWeb.FallbackController

  def create(conn, %{"username" => username, "password" => password} = args) do
    # rabbit decided to misbehave and pass even the local auth thru rabbitauth so we're doing a short circuit
    envauth = Application.get_env(:room_hermes, :rabbit)
    cond do
        username == envauth[:username] && password == envauth[:password] -> send_resp(conn, :ok, "allow")
        true ->
            case args["client_id"] == username do
              true ->
                case Accounts.find_rabbit_user(username, password) do
                  nil -> send_resp(conn, :ok, "deny")
                  val -> send_resp(conn, :ok, "allow")
                end
              false -> send_resp(conn, :ok, "deny")
            end
        end

  end
end