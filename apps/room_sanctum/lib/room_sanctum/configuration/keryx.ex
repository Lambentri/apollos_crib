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
end
