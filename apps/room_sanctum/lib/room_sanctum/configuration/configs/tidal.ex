defmodule RoomSanctum.Configuration.Configs.Tidal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
  end

  def changeset(source, params) do
    source
    |> cast(params, [])
    |> validate_required([])
  end
end