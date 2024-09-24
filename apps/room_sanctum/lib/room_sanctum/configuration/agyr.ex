defmodule RoomSanctum.Configuration.Agyr do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_webhooks" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :user, Ecto.UUID
    field :path, Ecto.UUID
    field :token, :string
    field :designator, :string

    timestamps()
  end

  @doc false
  def changeset(agyr, attrs) do
    agyr
    |> cast(attrs, [:designator, :path, :user, :token, :source_id])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:designator, :path, :user, :token])
  end
end
