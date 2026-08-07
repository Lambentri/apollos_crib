defmodule RoomIcarus.Airports do
  @moduledoc """
  Airport coordinate lookup, used to turn a destination code into the point an
  in-flight ETA is measured against.

  Data is vendored from https://github.com/datasets/airport-codes, filtered at
  build time to the 8800 entries that have an IATA code, a real airport type
  (large/medium/small -- no heliports, seaplane bases, or closed fields), and
  parseable coordinates. IATA codes are unique across that set.

  The table is baked in at compile time so lookups are a plain map fetch with no
  runtime IO.
  """

  # Tab separated rather than CSV: 153 airport names contain commas, and a
  # delimiter that never appears in the data avoids needing a quoting parser
  # here at compile time.
  @airports_tsv Path.join(__DIR__, "../../priv/airports.tsv")
  @external_resource @airports_tsv

  @airports @airports_tsv
            |> File.read!()
            |> String.split("\n", trim: true)
            |> Enum.drop(1)
            |> Enum.reduce(%{}, fn line, acc ->
              case String.split(line, "\t") do
                [iata, icao, name, municipality, lat, lon] ->
                  airport = %{
                    iata: iata,
                    icao: icao,
                    name: name,
                    municipality: municipality,
                    lat: String.to_float(lat),
                    lon: String.to_float(lon)
                  }

                  acc = Map.put(acc, iata, airport)
                  if icao == "", do: acc, else: Map.put_new(acc, icao, airport)

                _ ->
                  acc
              end
            end)

  @doc """
  Look up an airport by IATA (BOS) or ICAO (KBOS) code. Case insensitive.
  """
  def get(nil), do: nil

  def get(code) when is_binary(code) do
    Map.get(@airports, code |> String.trim() |> String.upcase())
  end

  def get(_), do: nil

  @doc "Coordinates as a `{lat, lon}` tuple, or nil if the code is unknown."
  def coordinates(code) do
    case get(code) do
      %{lat: lat, lon: lon} -> {lat, lon}
      nil -> nil
    end
  end

  @doc """
  IANA timezone for an airport, derived from its coordinates.

  Arrival times on a ticket are wall-clock at the destination, so this is what
  scheduled times are interpreted and displayed in -- not the server's zone and
  not UTC.
  """
  def timezone(code) do
    case coordinates(code) do
      {lat, lon} -> lat |> WhereTZ.lookup(lon) |> normalize_tz()
      nil -> nil
    end
  end

  # WhereTZ hands back a list where zone polygons overlap.
  defp normalize_tz(tz) when is_binary(tz), do: tz
  defp normalize_tz([tz | _]), do: normalize_tz(tz)
  defp normalize_tz(_), do: nil

  @doc "Number of distinct codes in the table (IATA plus ICAO aliases)."
  def count, do: map_size(@airports)

  @doc """
  Great-circle distance in nautical miles between two `{lat, lon}` points.

  Used for ETA, so the haversine approximation is far more precise than the
  underlying guess that the aircraft flies straight to the field.
  """
  def distance_nm({lat1, lon1}, {lat2, lon2}) do
    earth_radius_nm = 3440.065
    rad = &(&1 * :math.pi() / 180)

    dlat = rad.(lat2 - lat1)
    dlon = rad.(lon2 - lon1)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(rad.(lat1)) * :math.cos(rad.(lat2)) *
          :math.sin(dlon / 2) * :math.sin(dlon / 2)

    earth_radius_nm * 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
  end
end
