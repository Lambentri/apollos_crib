defmodule RoomSanctum.JSON do
  @moduledoc """
  JSON encoding that writes what Poison wrote, through Jason.

  What goes out over MQTT, and into the previews, is whatever the sources
  and condensers hand over: plain maps mostly, but also Ecto schemas,
  embeds, `{lon, lat}` tuples and Decimals. Poison encoded all of it --
  any struct as its fields, a tuple as a list (the old `TupleEncoder`),
  a Decimal as a bare number. Jason refuses a struct it has not been told
  about and has no tuples at all, so handed the same data it would raise
  in the middle of a publish. This turns the data into the shape Poison
  produced first, so the payloads the clients read do not change.

  Plain decoding needs none of this: `Jason.decode/2` reads what
  `Poison.decode/2` read.
  """

  @doc "As `Jason.encode!/2`, after `normalize/1`."
  def encode!(term, opts \\ []), do: term |> normalize() |> Jason.encode!(opts)

  @doc "As `Jason.encode/2`, after `normalize/1`."
  def encode(term, opts \\ []), do: term |> normalize() |> Jason.encode(opts)

  @doc """
  `term` with everything Jason would refuse made into what Poison wrote
  for it, and every map made a `Jason.OrderedObject` in the key order
  Poison wrote. Dates and times are left alone: both write them as ISO 8601.
  """
  def normalize(%struct{} = value) when struct in [Date, Time, NaiveDateTime, DateTime], do: value
  def normalize(%Jason.Fragment{} = value), do: value
  def normalize(%Decimal{} = value), do: value |> Decimal.to_string() |> Jason.Fragment.new()
  def normalize(%URI{} = value), do: URI.to_string(value)
  def normalize(%Range{} = value), do: Enum.to_list(value)
  def normalize(%MapSet{} = value), do: value |> MapSet.to_list() |> normalize()
  def normalize(%_{} = value), do: value |> Map.from_struct() |> normalize()
  # Poison wrote an object's keys in the reverse of the map's own order (it
  # folds over `Map.keys/1`, prepending), and Jason writes them in that order.
  # A client that reads a board in the order it arrived -- the Android app
  # lays its cards out that way -- would see them flip, so the order Poison
  # wrote is kept.
  def normalize(value) when is_map(value) do
    values = :lists.foldl(&[{&1, normalize(Map.fetch!(value, &1))} | &2], [], Map.keys(value))
    %Jason.OrderedObject{values: values}
  end

  def normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  def normalize(value) when is_tuple(value), do: value |> Tuple.to_list() |> normalize()
  def normalize(value), do: value
end
