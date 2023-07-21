defmodule RoomSanctum.Configuration.Configs.Gitlab do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
    field :pat, :string
    field :projects, {:array, :string}
  end

  def changeset(source, params) do
    source
    |> cast(params, [:url, :pat, :projects])
    |> validate_required([:url, :pat])
  end
end
