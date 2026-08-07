defmodule RoomTreasury.Currencies do
  @moduledoc """
  The catalogue of tradeable codes, grouped for the query form.

  Vendored from the exchange-api's own `currencies.json` and classified into
  currency / metal / crypto at build time, so the form needs no network call to
  render and the grouping cannot shift under a user mid-edit.

  Classification is by ISO 4217 membership first, then by name for the legacy
  and regional currencies the API still carries (Deutsche Mark, French Franc,
  Jersey Pound). Stablecoins are pinned to crypto explicitly -- "Gemini US
  Dollar" is a token, not a currency, and would otherwise read as one.
  """

  @catalogue_tsv Path.join(__DIR__, "../../priv/currencies.tsv")
  @external_resource @catalogue_tsv

  @entries @catalogue_tsv
           |> File.read!()
           |> String.split("\n", trim: true)
           |> Enum.drop(1)
           |> Enum.flat_map(fn line ->
             case String.split(line, "\t") do
               [code, name, category] -> [%{code: code, name: name, category: category}]
               _ -> []
             end
           end)

  @by_code Map.new(@entries, &{&1.code, &1})

  @group_order ["currency", "metal", "crypto"]
  @group_labels %{"currency" => "Currencies", "metal" => "Metals", "crypto" => "Crypto"}

  def all, do: @entries
  def get(code) when is_binary(code), do: Map.get(@by_code, String.downcase(String.trim(code)))
  def get(_), do: nil
  def known?(code), do: get(code) != nil
  def name(code), do: (get(code) || %{}) |> Map.get(:name)
  def count, do: length(@entries)

  @doc "Codes in one group, as `{label, value}` pairs sorted by name."
  def options(category) do
    @entries
    |> Enum.filter(&(&1.category == category))
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&{"#{&1.name} (#{String.upcase(&1.code)})", &1.code})
  end

  @doc """
  Every group as `{group_label, options}`, ready for a grouped `<select>`.

  Currencies first, then metals, then crypto -- the order someone reaches for
  them in.
  """
  def grouped, do: grouped(@group_order)

  @doc """
  Only the requested groups, in the canonical order.

  An empty or unrecognised list falls back to everything rather than rendering
  an empty dropdown.
  """
  def grouped(categories) when is_list(categories) do
    wanted = MapSet.new(categories, &to_string/1)

    case Enum.filter(@group_order, &MapSet.member?(wanted, &1)) do
      [] -> grouped(@group_order)
      kept -> Enum.map(kept, fn c -> {@group_labels[c], options(c)} end)
    end
  end

  def grouped(_), do: grouped(@group_order)
end
