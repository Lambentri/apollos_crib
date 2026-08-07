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

    # USPS is polled rather than subscribed to, but the OAuth dance is the same
    # shape as UPS: client credentials in, bearer token cached until it expires.
    field :apikey_usps_id, :string
    field :apikey_usps_secret, :string
    field :token_usps, :string
    field :token_usps_expiry, :string
    # Shared with USPS when subscribing; used to verify the HMAC on the way back.
    field :usps_webhook_secret, :string

    field :apikey_uniuni, :string
    field :handle_usps, :boolean, default: true

    # Which :mailbox source to pull parcel mail from. Left blank, this source
    # only receives mail pushed at the SMTP listener.
    field :mailbox_source_id, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, [
      :apikey_ups_id, :apikey_ups_secret, :token_ups, :token_ups_expiry, 
      :apikey_fedex_id, :apikey_fedex_secret, :token_fedex, :token_fedex_expiry,
      :apikey_dhl_id, :apikey_dhl_secret, :token_dhl, :token_dhl_expiry,
      :apikey_usps_id, :apikey_usps_secret, :token_usps, :token_usps_expiry,
      :usps_webhook_secret,
      :apikey_uniuni, :handle_usps, :mailbox_source_id])
    |> validate_required([])
  end
end
