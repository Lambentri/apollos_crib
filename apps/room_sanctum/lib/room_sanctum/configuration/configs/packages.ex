defmodule RoomSanctum.Configuration.Configs.Packages do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :apikey_ups, :string
    field :apikey_fedex, :string
    field :apikey_uniuni, :string
    field :handle_usps, :boolean, default: true
  end

  def changeset(source, params) do
    source
    |> cast(params, [:apikey_ups, :apikey_fedex, :apikey_uniuni, :handle_usps])
    |> validate_required([])
  end
end
