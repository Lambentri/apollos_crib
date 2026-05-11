defmodule RoomSanctum.Configuration.Configs.Pollen do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :api_key, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, [:api_key])
    |> validate_required([:api_key])
  end
end
