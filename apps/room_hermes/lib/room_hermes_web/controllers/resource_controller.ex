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
        case name do
          # Write is allowed at the exchange so a client can talk back --
          # a phone reporting where it is, for a foci that travels with it.
          # What it may write is not decided here: the topic check that
          # follows confines a client to its own uplink prefix, and this
          # would be far too broad on its own.
          "amq.topic" ->
            case permission do
              "read" -> send_resp(conn, :ok, "allow")
              "write" -> send_resp(conn, :ok, "allow")
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
