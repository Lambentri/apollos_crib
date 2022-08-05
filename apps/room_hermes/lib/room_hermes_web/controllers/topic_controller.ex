defmodule RoomHermesWeb.TopicController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback(RoomHermesWeb.FallbackController)

  def create(conn, %{
        "username" => username,
        "vhost" => vhost,
        "resource" => resource,
        "name" => name,
        "permission" => permission,
        "routing_key" => routing_key
      }) do
    user = Accounts.find_rabbit_user(username)

    case vhost do
      "/" ->
        case resource do
          "topic" ->
            case name do
              "amq.topic" ->
                if routing_key == user.topic do
                  send_resp(conn, :ok, "allow")
                else
                  send_resp(conn, :ok, "deny")
                end

              _otherwise ->
                send_resp(conn, :ok, "deny")
            end

          _otherwise ->
            send_resp(conn, :ok, "deny")
        end

      _otherwise ->
        send_resp(conn, :ok, "deny")
    end
  end
end
