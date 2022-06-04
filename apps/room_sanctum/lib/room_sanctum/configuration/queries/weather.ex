defmodule RoomSanctum.Configuration.Queries.Weather do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :lat, :string
    field :lon, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(lat lon)a)
    |> validate_required([:lat, :lon])
  end
end