defmodule RoomHermesWeb.ResourceController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback(RoomHermesWeb.FallbackController)

  def create(conn, %{
        "username" => username,
        "vhost" => vhost,
        "resource" => resource,
        "name" => name,
        "permission" => permission
      }) do
    case {vhost, resource} do
      {"/", "queue"} ->
        IO.puts("qqq")
        case name |> String.starts_with?("mqtt-subscription") do
          true -> send_resp(conn, :ok, "allow")
          false -> send_resp(conn, :ok, "deny")
        end

      {"/", "exchange"} ->
        IO.puts("exch")
        case name do
          "amq.topic" ->
            case permission do
              "read" -> send_resp(conn, :ok, "allow")
              _otherwise -> send_resp(conn, :ok, "deny")
            end

          _otherwise ->
            send_resp(conn, :ok, "deny")
        end

      _otherwise ->
        send_resp(conn, :ok, "deny")
    end
  end
end
