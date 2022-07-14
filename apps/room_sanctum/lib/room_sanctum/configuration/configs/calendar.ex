defmodule RoomSanctum.Configuration.Configs.Calendar do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(url)a)
    |> validate_required(:url)
  end
end
