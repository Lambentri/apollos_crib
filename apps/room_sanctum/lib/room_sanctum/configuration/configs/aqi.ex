defmodule RoomSanctum.Configuration.Configs.AQI do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
#    field :api_key, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, [])
    |> validate_required([])
  end
end
