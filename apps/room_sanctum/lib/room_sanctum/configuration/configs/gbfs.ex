defmodule RoomSanctum.Configuration.Configs.GBFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
    field :lang, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(url lang)a)
    |> validate_required([:url, :lang])
  end
end