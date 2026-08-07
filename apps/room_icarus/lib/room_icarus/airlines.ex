defmodule RoomIcarus.Airlines do
  @moduledoc """
  IATA to ICAO airline code translation.

  Aircraft transmit the ICAO callsign over ADS-B, not the IATA flight number on
  the ticket: "UA 558" is in the air as `UAL558`. Querying adsb.fi for `UA558`
  returns nothing, so anything a user types has to be normalized first.

  There is no free comprehensive airline code dataset in the airport-codes repo,
  so this is a hand-maintained table of carriers likely to matter for a pickup.
  A three-letter prefix is passed through untouched, which is the escape hatch
  when a carrier is missing: type the ICAO callsign directly.
  """

  @iata_to_icao %{
    # US mainline
    "AA" => "AAL",
    "AS" => "ASA",
    "B6" => "JBU",
    "DL" => "DAL",
    "F9" => "FFT",
    "G4" => "AAY",
    "HA" => "HAL",
    "NK" => "NKS",
    "SY" => "SCX",
    "UA" => "UAL",
    "WN" => "SWA",
    # US regional
    "9E" => "EDV",
    "MQ" => "ENY",
    "OH" => "JIA",
    "OO" => "SKW",
    "YX" => "RPA",
    # Canada / Mexico
    "AC" => "ACA",
    "AM" => "AMX",
    "WS" => "WJA",
    "Y4" => "VOI",
    # Europe
    "AF" => "AFR",
    "AY" => "FIN",
    "AZ" => "ITY",
    "BA" => "BAW",
    "DY" => "NOZ",
    "EI" => "EIN",
    "EW" => "EWG",
    "FR" => "RYR",
    "IB" => "IBE",
    "KL" => "KLM",
    "LH" => "DLH",
    "LX" => "SWR",
    "OS" => "AUA",
    "SK" => "SAS",
    "TP" => "TAP",
    "U2" => "EZY",
    "VS" => "VIR",
    "W6" => "WZZ",
    # Middle East / Asia / Oceania
    "AI" => "AIC",
    "BR" => "EVA",
    "CI" => "CAL",
    "CX" => "CPA",
    "EK" => "UAE",
    "ET" => "ETH",
    "EY" => "ETD",
    "JL" => "JAL",
    "KE" => "KAL",
    "NH" => "ANA",
    "NZ" => "ANZ",
    "QF" => "QFA",
    "QR" => "QTR",
    "SQ" => "SIA",
    "TG" => "THA",
    "TK" => "THY",
    # Latin America
    "AV" => "AVA",
    "CM" => "CMP",
    "LA" => "LAN"
  }

  @doc "The airline codes this table knows, for surfacing in the UI."
  def known, do: @iata_to_icao

  @doc """
  Turn user input like "UA 558", "ua558", or "UAL558" into the ADS-B callsign
  `UAL558`. Returns nil when the airline prefix is not recognised and is not
  already a 3-letter ICAO code.
  """
  def callsign(nil), do: nil

  def callsign(input) when is_binary(input) do
    normalized =
      input
      |> String.upcase()
      |> String.replace(~r/[^A-Z0-9]/, "")

    case Regex.run(~r/^([A-Z0-9]{2,3}?)(\d{1,4}[A-Z]?)$/, normalized) do
      [_, prefix, number] -> resolve(prefix, number, normalized)
      _ -> nil
    end
  end

  def callsign(_), do: nil

  # A 2-character prefix is IATA and must be translated. A 3-character prefix is
  # already ICAO -- but only trust it when we cannot read it as a known IATA
  # code, since e.g. "AA1" would otherwise parse its prefix as "AA1".
  defp resolve(prefix, number, normalized) do
    cond do
      Map.has_key?(@iata_to_icao, prefix) ->
        @iata_to_icao[prefix] <> number

      String.length(prefix) == 3 and String.match?(prefix, ~r/^[A-Z]{3}$/) ->
        normalized

      true ->
        nil
    end
  end
end
