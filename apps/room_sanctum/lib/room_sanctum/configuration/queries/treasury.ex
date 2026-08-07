defmodule RoomSanctum.Configuration.Queries.Treasury do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  One currency pair to price, `from` against `to`.

  Both sides are picked from the catalogue in `RoomTreasury.Currencies`, which
  groups the API's 338 codes into currencies, metals and crypto -- so the pair is
  chosen rather than typed, and an unknown code cannot be saved.
  """

  embedded_schema do
    field :from, :string
    field :to, :string
    # Sub-1 rates keep this many significant digits instead of decimals, so a
    # BTC pair does not render as 0.0000.
    field :precision, :integer, default: 4
  end

  def changeset(source, params) do
    source
    |> cast(params, [:from, :to, :precision])
    |> downcase(:from)
    |> downcase(:to)
    |> validate_required([:from, :to])
    |> validate_number(:precision, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_known(:from)
    |> validate_known(:to)
    |> validate_distinct()
  end

  @doc "The pair as the worker wants it, e.g. `usd/eur`."
  def pair(%__MODULE__{from: from, to: to}) when is_binary(from) and is_binary(to),
    do: "#{from}/#{to}"

  def pair(_), do: nil

  defp downcase(changeset, field) do
    case get_change(changeset, field) do
      value when is_binary(value) -> put_change(changeset, field, String.downcase(String.trim(value)))
      _ -> changeset
    end
  end

  defp validate_known(changeset, field) do
    case get_field(changeset, field) do
      nil ->
        changeset

      code ->
        if RoomTreasury.Currencies.known?(code) do
          changeset
        else
          add_error(changeset, field, "unknown currency code")
        end
    end
  end

  # Pricing something against itself is always 1 and is almost certainly a slip.
  defp validate_distinct(changeset) do
    from = get_field(changeset, :from)
    to = get_field(changeset, :to)

    if is_binary(from) and from == to do
      add_error(changeset, :to, "pick something different from the base")
    else
      changeset
    end
  end
end
