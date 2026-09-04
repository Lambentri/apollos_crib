defmodule RoomGbfs.V3 do
  @moduledoc """
  Reading a GBFS v3 feed as though it were v2.

  v3 renamed things rather than adding them, which is the awkward kind of
  change: a v3 feed parses without complaint against a v2 reader and comes out
  empty, because `num_vehicles_available` is simply not a field anyone asked
  for and Ecto's `cast/3` drops what it was not told about. No error, no log, a
  station with no bikes in it.

  So this translates a v3 record into the v2 shape the schemas, condensers and
  clients already speak, rather than teaching every one of them both dialects.

  **Every function here is idempotent and version-blind.** A v2 record has
  `num_bikes_available` and no `num_vehicles_available`, so the rename is a
  no-op; a v3 record has the reverse. That is deliberate: it means nothing
  upstream has to know which version it is holding, and there is no version
  flag to thread through -- or to get wrong for the one operator who publishes
  a v3 document with a v2 version string in it.

  The one field with no direct counterpart is `num_ebikes_available`, which v3
  dropped. It is recovered rather than abandoned: `vehicle_types_available`
  counts each type at the station and `vehicle_types.json` says which types are
  electric, so the two together give the number back. That needs the types
  loaded first, which is why `feed_order/1` exists.
  """


  @doc """
  The feed list out of a discovery document, whichever version wrote it.

  Told apart by shape rather than by the `version` field. v2 keys `data` by
  language -- `data.en.feeds` -- and v3 dropped that, so `data.feeds` is a list
  in v3 and cannot be one in v2. Shape is the thing that actually has to be
  true for the parse to work; the version string is a claim about it.

  Returns `{:ok, version, feeds}`, or `{:error, languages}` for a v2 document
  that does not carry the language the source is configured for -- which is the
  one case worth reporting to the operator, since it is a setting they chose.
  """
  def feeds(%{"data" => %{"feeds" => feeds}}, _lang) when is_list(feeds), do: {:ok, :v3, feeds}

  def feeds(%{"data" => data}, lang) when is_map(data) do
    case Map.get(data, lang) do
      %{"feeds" => feeds} when is_list(feeds) -> {:ok, :v2, feeds}
      _ -> {:error, Map.keys(data)}
    end
  end

  def feeds(_body, _lang), do: {:error, []}

  @doc """
  The v2 name for a feed.

  v3 renamed `free_bike_status` to `vehicle_status` -- the only rename among
  the feeds this reads. `system_hours` and `system_calendar` were removed
  outright rather than renamed, so they simply stop arriving.
  """
  def feed_name("vehicle_status"), do: "free_bike_status"
  def feed_name(name), do: name

  @doc """
  A station's status, in v2 terms.

  v3 counts vehicles where v2 counted bikes, which is the honest name for a
  system that rents scooters -- but it is a rename, and a reader looking for
  the old key finds nothing rather than failing.
  """
  def station_status(row, electric_ids \\ nil) do
    row
    |> rename(:num_vehicles_available, :num_bikes_available)
    |> rename(:num_vehicles_disabled, :num_bikes_disabled)
    |> derive_ebikes(electric_ids)
  end

  @doc """
  The order to read the feeds in.

  Operators list them alphabetically or however their generator felt, and for
  every feed but one the order does not matter. `station_status` needs the
  vehicle types already stored to work out how many of the bikes at a station
  are electric, and the two PBSC systems list `vehicle_types` last -- so left
  alone, the electric count would be a refresh behind for ever.
  """
  def feed_order(%{"name" => name}), do: feed_order(name)
  def feed_order("vehicle_types"), do: 0
  def feed_order(_name), do: 1

  @doc """
  The vehicle type ids that count as electric, from `Storage.gbfs_vehicle_types/1`.

  Assist and full electric both; combustion and hybrid do not, and a car share
  publishing those has no business reporting an e-bike count at all.
  """
  @electric ~w(electric electric_assist)

  def electric_type_ids(vehicle_types) when is_map(vehicle_types) do
    vehicle_types
    |> Enum.filter(fn {_id, type} -> to_string(type.propulsion_type) in @electric end)
    |> MapSet.new(fn {id, _type} -> to_string(id) end)
  end

  # v3 has no num_ebikes_available. Where the station breaks its count down by
  # type and the types are known, the number is simply the electric ones added
  # up. Anything already carrying the field -- a v2 feed, or Lyft's extension
  # of it -- keeps what it had.
  defp derive_ebikes(row, nil), do: row

  defp derive_ebikes(%{num_ebikes_available: count} = row, _electric) when is_integer(count),
    do: row

  defp derive_ebikes(%{vehicle_types_available: types} = row, electric) when is_list(types) do
    count =
      Enum.reduce(types, 0, fn type, acc ->
        if to_string(Map.get(type, :vehicle_type_id)) in electric do
          acc + (Map.get(type, :count) || 0)
        else
          acc
        end
      end)

    Map.put(row, :num_ebikes_available, count)
  end

  defp derive_ebikes(row, _electric), do: row

  @doc """
  A loose vehicle, in v2 terms.

  `vehicle_status.json` in v3, `free_bike_status.json` in v2, and the id
  changed name with the file. The id matters more than most: it is half the
  conflict target these rows are written on, so a null one collapses every
  bike in the feed onto a single row.
  """
  def vehicle_status(row), do: rename(row, :vehicle_id, :bike_id)

  @doc """
  A station's description, in v2 terms.

  v3 made `name` a list of `{text, language}` rather than a string, so that a
  bilingual city can publish both. The schema holds one string, so one is
  chosen -- the configured language where the feed offers it.
  """
  def station_info(row, lang) do
    row
    |> localize(:name, lang)
    |> localize(:short_name, lang)
  end

  @doc "A vehicle type, in v2 terms."
  def vehicle_types(row, lang), do: localize(row, :name, lang)

  @doc """
  A system's own description, in v2 terms.

  Same localisation as everywhere else, plus `languages`: v3 made it a list,
  on the same reasoning that made the names lists.
  """
  def system_information(row, lang) do
    row
    |> localize(:name, lang)
    |> localize(:short_name, lang)
    |> localize(:operator, lang)
    |> first_language()
  end

  @doc """
  One string out of a v3 localised value.

  `[%{text: "Bicing", language: "ca"}]` in v3, `"Bicing"` in v2, and a bare
  string is returned untouched -- which is what makes this safe to run over a
  v2 feed.

  Prefers the language asked for, then falls back to the first the feed gives
  rather than to nothing: a name in the wrong language is still a name, and an
  operator who publishes only Catalan should not read as an unnamed station.
  """
  def text(value, lang \\ nil)

  def text([%{} | _] = localized, lang) do
    match =
      Enum.find(localized, fn entry ->
        lang != nil and to_string(Map.get(entry, :language)) == to_string(lang)
      end)

    entry = match || List.first(localized)
    Map.get(entry, :text)
  end

  def text(value, _lang), do: value

  defp localize(row, key, lang) do
    case Map.fetch(row, key) do
      {:ok, value} -> Map.put(row, key, text(value, lang))
      :error -> row
    end
  end

  # v3 publishes `languages: ["ca", "es"]`; the schema holds one.
  defp first_language(%{languages: [first | _]} = row), do: Map.put(row, :language, first)
  defp first_language(row), do: row

  # Moves a key only when the old name is absent, so running this over a v2
  # record that already has the destination cannot overwrite it.
  defp rename(row, from, to) do
    case Map.fetch(row, from) do
      {:ok, value} -> row |> Map.delete(from) |> Map.put_new(to, value)
      :error -> row
    end
  end
end
