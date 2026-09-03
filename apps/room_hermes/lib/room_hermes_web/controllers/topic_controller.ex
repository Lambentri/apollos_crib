defmodule RoomHermesWeb.TopicController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback(RoomHermesWeb.FallbackController)

  @doc """
  Which routing keys a rabbit user may read and write.

  Reading is the whole of its own topic: the board, the image beside it, and
  anything else a Pythiae publishes there.

  Writing is confined to an uplink prefix, `<topic>.up.`. A client is not
  allowed to write the topic a Pythiae publishes on, because everything else
  subscribed to that Ankyra -- a panel on a wall, a phone in a pocket -- would
  believe what it said. The uplink is a different direction on the same
  connection, not the same channel back to front.
  """
  def create(conn, %{
        "username" => username,
        "vhost" => "/",
        "resource" => "topic",
        "name" => "amq.topic",
        "permission" => permission,
        "routing_key" => routing_key
      }) do
    case Accounts.find_rabbit_user(username) do
      nil ->
        send_resp(conn, :ok, "deny")

      user ->
        if permitted?(user.topic, permission, routing_key) do
          send_resp(conn, :ok, "allow")
        else
          send_resp(conn, :ok, "deny")
        end
    end
  end

  def create(conn, _params), do: send_resp(conn, :ok, "deny")

  @doc """
  Whether a routing key is permitted, given the user's own topic.

  Public because it is the whole of the rule and worth exercising directly.
  There is no test here doing so: this app has no runnable test suite, its
  migrations expecting tables the sanctum repo owns, and giving it one is its
  own piece of work. Until then:

      mix run --no-start -e 'IO.inspect RoomHermesWeb.TopicController.permitted?("T", "write", "T.up.loc")'
  """
  def permitted?(topic, "read", routing_key), do: String.starts_with?(routing_key, topic)

  def permitted?(topic, "write", routing_key),
    do: Enum.any?(uplink_prefixes(topic), &String.starts_with?(routing_key, &1))

  def permitted?(_topic, _permission, _routing_key), do: false

  @doc """
  Where a client may publish to, for a given Ankyra topic.

  Two channels, both inbound:

    * `<topic>.up.` — what the client is, most of it what it knows about
      itself. A location, for a foci that travels with the phone.
    * `<topic>.publish.` — what the client wants, which is currently a board.
      A Pythiae publishes on change and on its own tick, so a client that has
      just woken up can be looking at something old; this is how it asks.

  Named here rather than in each caller so the two ends of the rule cannot
  drift: this is both what the broker allows and what a client should send to.
  """
  def uplink_prefixes(topic), do: [topic <> ".up.", topic <> ".publish."]

  @doc "The uplink a client reports itself on."
  def uplink_prefix(topic), do: topic <> ".up."

  @doc "The channel a client asks for something on."
  def request_prefix(topic), do: topic <> ".publish."
end
