defmodule RoomSanctum.Configuration.Queries.Ephem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :lat, :float
    field :lon, :float
  end

  def changeset(source, params) do
    source
    |> cast(params, [:lat, :lon])
    |> validate_required([:lat, :lon])
  end
end