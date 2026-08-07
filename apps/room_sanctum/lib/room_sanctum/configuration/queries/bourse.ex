defmodule RoomSanctum.Configuration.Queries.Bourse do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  One ticker symbol, in Yahoo's own notation.

  That covers more than equities: `^GSPC` for an index, `BTC-USD` for crypto,
  `TSCO.L` for a London listing. The symbol is not validated against a
  catalogue -- there isn't one to validate against -- so a bad symbol surfaces
  as Yahoo's own "may be delisted" message on the card rather than a form error.
  """

  embedded_schema do
    field :symbol, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, [:symbol])
    |> upcase_symbol()
    |> validate_required([:symbol])
    |> validate_format(:symbol, ~r/^[A-Z0-9.\-=^]{1,20}$/,
      message: "letters, digits and . - = ^ only, e.g. AAPL, ^GSPC, BTC-USD"
    )
  end

  defp upcase_symbol(changeset) do
    case get_change(changeset, :symbol) do
      value when is_binary(value) ->
        put_change(changeset, :symbol, value |> String.trim() |> String.upcase())

      _ ->
        changeset
    end
  end
end
