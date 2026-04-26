defmodule RoomHermesWeb.UserController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts

  action_fallback RoomHermesWeb.FallbackController

  def create(conn, %{"username" => username, "password" => password, "client_id" => client_id}) do
    case Accounts.find_rabbit_user(username, password) do
      nil ->
        send_resp(conn, :ok, "deny")

      rabbit_user ->
        cond do
          client_id in rabbit_user.client_ids ->
            send_resp(conn, :ok, "allow")

          rabbit_user.auto_register_clients ->
            Accounts.update_rabbit_user(rabbit_user, %{
              client_ids: Enum.uniq([client_id | rabbit_user.client_ids])
            })

            send_resp(conn, :ok, "allow")

          true ->
            send_resp(conn, :ok, "deny")
        end
    end
  end

  def create(conn, %{"username" => username, "password" => password}) do
    case Accounts.find_rabbit_user(username, password) do
      nil -> send_resp(conn, :ok, "deny")
      _ -> send_resp(conn, :ok, "allow")
    end
  end
end
