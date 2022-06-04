defmodule RoomSanctum.Configuration.Queries.Hass do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :entity, :string
    field :properties, {:array, :string}
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(entity, properties)a)
    |> validate_required([:entity, :properties])
  end
end