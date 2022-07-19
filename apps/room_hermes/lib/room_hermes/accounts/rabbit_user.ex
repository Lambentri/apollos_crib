defmodule RoomHermes.Accounts.RabbitUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users_rabbit" do
    field :password, :string
    field :username, :string
    belongs_to :user, RoomSanctum.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(rabbit_user, attrs) do
    rabbit_user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
  end
end
