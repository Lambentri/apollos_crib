defmodule RoomSanctum.Configuration.Configs.Treasury do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Exchange rates from fawazahmed0's exchange-api.

  No key and no rate limits, so the only setting is which groups of the 338
  available codes should be offered when building a query. Someone tracking
  holiday money has no use for 148 crypto tokens in the dropdown.
  """

  @categories ~w(currency metal crypto)

  def categories, do: @categories

  embedded_schema do
    # Empty means show everything -- an offering with nothing ticked should not
    # leave the query form unusable.
    field :categories, {:array, :string}, default: @categories
  end

  def changeset(source, params) do
    source
    |> cast(params, [:categories])
    |> clean_categories()
    |> validate_subset(:categories, @categories)
  end

  @doc "The groups a query form should offer, falling back to all of them."
  def enabled_categories(%__MODULE__{categories: cats}) when is_list(cats) and cats != [], do: cats
  def enabled_categories(_), do: @categories

  # Checkbox groups submit a blank entry so that unticking everything still
  # sends the key; strip it rather than storing "".
  defp clean_categories(changeset) do
    case get_change(changeset, :categories) do
      nil ->
        changeset

      values ->
        put_change(changeset, :categories, values |> List.wrap() |> Enum.reject(&(&1 in ["", nil])))
    end
  end
end
