defmodule RoomSanctum.Configuration.Configs.Packages do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :apikey_ups_id, :string
    field :apikey_ups_secret, :string
    field :token_ups, :string
    field :token_ups_expiry, :string
    
    field :apikey_fedex_id, :string
    field :apikey_fedex_secret, :string
    field :token_fedex, :string
    field :token_fedex_expiry, :string

    field :apikey_dhl_id, :string
    field :apikey_dhl_secret, :string
    field :token_dhl, :string
    field :token_dhl_expiry, :string

    field :apikey_uniuni, :string
    field :handle_usps, :boolean, default: true
  end

  def changeset(source, params) do
    source
    |> cast(params, [
      :apikey_ups_id, :apikey_ups_secret, :token_ups, :token_ups_expiry, 
      :apikey_fedex_id, :apikey_fedex_secret, :token_fedex, :token_fedex_expiry,
      :apikey_dhl_id, :apikey_dhl_secret, :token_dhl, :token_dhl_expiry,
      :apikey_uniuni, :handle_usps])
    |> validate_required([])
  end
end
