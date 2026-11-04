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
    send_resp(conn, :ok, decide(vhost, resource, name, permission))
  end

  defp decide("/", "queue", name, _permission) do
    IO.puts("qqq")

    case name |> String.starts_with?("mqtt-subscription") do
      true -> "allow"
      false -> "deny"
    end
  end

  # Write is allowed at the exchange so a client can talk back --
  # a phone reporting where it is, for a foci that travels with it.
  # What it may write is not decided here: the topic check that
  # follows confines a client to its own uplink prefix, and this
  # would be far too broad on its own.
  defp decide("/", "exchange", "amq.topic", permission) when permission in ["read", "write"],
    do: "allow"

  defp decide(_vhost, _resource, _name, _permission), do: "deny"
end
