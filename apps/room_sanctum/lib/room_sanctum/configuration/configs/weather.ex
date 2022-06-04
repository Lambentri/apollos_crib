defmodule RoomSanctum.Configuration.Configs.Weather do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :base_url, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(base_url)a)
    |> validate_required([:base_url])
  end
end