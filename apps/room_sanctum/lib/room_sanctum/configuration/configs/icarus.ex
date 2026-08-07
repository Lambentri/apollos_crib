defmodule RoomSanctum.Configuration.Configs.Icarus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  # adsb.fi's public endpoints need no credentials, so -- like the AirNow source
  # -- there is nothing to configure here beyond enabling it. The field exists so
  # feeders (who get the higher-rate snapshot endpoint via IP allowlisting) can
  # point at their own instance without a code change.
  embedded_schema do
    field :endpoint, :string, default: "https://opendata.adsb.fi/api/v3"
  end

  def changeset(source, params) do
    source
    |> cast(params, [:endpoint])
    |> validate_required([:endpoint])
  end
end
