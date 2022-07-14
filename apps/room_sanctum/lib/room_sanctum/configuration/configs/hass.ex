defmodule RoomSanctum.Configuration.Configs.Hass do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
    field :api_key, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(api_key url)a)
    |> validate_required([:api_key, :url])
  end
end
