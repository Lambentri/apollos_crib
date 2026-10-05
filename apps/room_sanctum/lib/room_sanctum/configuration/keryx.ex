defmodule RoomSanctum.Configuration.Keryx do
  use Ecto.Schema
  import Ecto.Changeset

  schema "keryxiae" do
    field :name, :string
    field :ttl, :integer
    field :query_ids, {:array, :integer}
    belongs_to :user, RoomSanctum.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(keryx, attrs) do
    keryx
    |> cast(attrs, [:name, :query_ids, :ttl, :user_id])
    |> foreign_key_constraint(:user_id)
    |> validate_required([:name, :query_ids, :ttl])
    |> unique_constraint(:name)
  end

  @doc """
  Where a Keryx publishes, as an AMQP routing key.

  Dotted, because the topic exchange splits on dots and nothing else: a key
  of `/apollos/keryx/<name>/gtfs/12` is one word, so nobody could subscribe to
  a Keryx without naming every key in it. Keyed by id rather than name, since
  a name may have a dot in it and an id never does.

      apollos.keryx.<id>.<type>.<query_id>           the query's results
      apollos.keryx.<id>.<type>.<query_id>.meta      the condensed summary
      apollos.keryx.<id>.<type>.<query_id>.<item>... single items
      apollos.keryx.<id>.control                     commands, inbound

  An MQTT client sees the same thing with slashes -- see `mqtt_topic/1`.
  Who may read and write them is `RoomHermesWeb.TopicController`'s to say.
  """
  def topic(keryx_id), do: "apollos.keryx.#{keryx_id}"

  @doc "Where a Keryx listens for commands."
  def control_topic(keryx_id), do: topic(keryx_id) <> ".control"

  @doc "A routing key as an MQTT client spells it: RabbitMQ swaps `.` for `/`."
  def mqtt_topic(routing_key), do: String.replace(routing_key, ".", "/")
end
