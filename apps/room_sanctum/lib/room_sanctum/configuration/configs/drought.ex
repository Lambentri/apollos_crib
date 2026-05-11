defmodule RoomSanctum.Configuration.Configs.Drought do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  # Supported product slugs. Only "usdm" has a working fetcher today;
  # the others are reserved for future implementation.
  @products ~w(usdm csi cpc gpcc)

  def supported_products, do: @products

  embedded_schema do
    field :products, {:array, :string}, default: ["usdm"]
  end

  def changeset(source, params) do
    source
    |> cast(params, [:products])
    |> validate_subset(:products, @products)
  end
end
