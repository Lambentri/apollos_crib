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

  What is *not* handled, and cannot be here: v3 has no `num_ebikes_available`.
  The electric count is derivable, but only by joining `vehicle_types_available`
  against `vehicle_types.json`, which is a different feed fetched separately
  and possibly later. A v3 station reports its total correctly and its electric
  count as nothing.
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
  def station_status(row) do
    row
    |> rename(:num_vehicles_available, :num_bikes_available)
    |> rename(:num_vehicles_disabled, :num_bikes_disabled)
  end

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
