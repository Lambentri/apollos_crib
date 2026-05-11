defmodule RoomSanctum.Configuration.Queries.Drought do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :product, :string, default: "usdm"
    field :fips, :string
    field :state, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, [:product, :fips, :state])
    |> validate_required([:product])
    |> validate_one_target()
  end

  defp validate_one_target(changeset) do
    fips = get_field(changeset, :fips)
    state = get_field(changeset, :state)

    case {fips, state} do
      {nil, nil} -> add_error(changeset, :fips, "must specify either FIPS county code or state")
      {"", ""} -> add_error(changeset, :fips, "must specify either FIPS county code or state")
      _ -> changeset
    end
  end
end
