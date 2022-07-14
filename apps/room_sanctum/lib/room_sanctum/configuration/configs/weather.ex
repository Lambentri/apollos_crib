defmodule RoomSanctum.Configuration.Configs.Weather do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :api_key, :string
    field :units, Ecto.Enum, values: [:standard, :metric, :imperial]
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(api_key units)a)
    |> validate_required([:api_key, :units])
  end
end
