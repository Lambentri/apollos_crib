defmodule RoomIcarus.Classify do
  @moduledoc """
  Sorts an aircraft into a rough operator class so area queries can filter.

  Only one of these is authoritative. `dbFlags` bit 0 is a real military marker
  maintained in the readsb database. Cargo and commercial have no flag anywhere
  in the feed, so they are inferred from the callsign's ICAO operator prefix,
  which is genuinely reliable for scheduled operators and useless for anything
  else.

  Known limits, all of which land in `:general`:

    * Belly freight on a passenger flight is indistinguishable from passengers.
    * Airlines that fly cargo under their passenger code (Emirates, Korean,
      LATAM) classify as `:commercial`.
    * Commercial is matched first on operator callsign, then on the operator
      name containing "AIRLINES"/"AIRWAYS". The name fallback is what catches
      regionals flying under a major's banner (CommutAir squawks UCA but is
      registered to United) without needing every code in a table.
    * Private and business aircraft usually squawk their registration as the
      callsign, so they correctly fall through to `:general`.
  """

  @classes ~w(commercial cargo military general)

  def classes, do: @classes

  # Dedicated freight operators, by ICAO callsign prefix.
  @cargo_prefixes ~w(
    ABW ABX ACX AJT ATN BOX CAO CJT CKK CKS CLX CMP DHK EXS FDX GEC GTI
    ICL JOS KYE LTG MPH NAC NCA PAC RCF SOO SQC TAY UPS WGN
  )
  |> MapSet.new()

  # Operator-name fallback for aircraft whose callsign is not a scheduled one.
  @cargo_keywords ~w(CARGO FREIGHT LOGISTICS FEDERAL\ EXPRESS PARCEL)

  # Scheduled carriers whose ICAO code is not derivable from the IATA table in
  # RoomIcarus.Airlines -- mostly regionals and carriers we do not track flights
  # for. The operator-name fallback below covers the long tail.
  @extra_commercial_prefixes ~w(
    AAR ABY ACA AEA AEE AHY ANZ APJ ARG ASH AUA AWI AZU BEL BTI CCA CEB CES
    CHH CQH CRK CSA CSN CTN ELY ETH EVA FDB GFA GIA GLO HDA HVN ICE IGO JNA
    KAC KAP LNI LOT MAS MSR OMA PAL PGT PIA PDT POE PTR QXE ROT SEJ SIL SVA
    SXS TAM TRA TSC TVF TWB UCA UZB VIV VJC VLG VTI
  )
  |> MapSet.new()

  @commercial_prefixes RoomIcarus.Airlines.known()
                       |> Map.values()
                       |> MapSet.new()
                       |> MapSet.union(@extra_commercial_prefixes)

  # Airline naming conventions, for operators whose callsign we do not know.
  # Checked only after the cargo rules, so "KALITTA AIR" stays cargo.
  @commercial_keywords ["AIRLINES", "AIRWAYS", "AIR LINES", "AIRLINE"]

  @doc """
  Classify a normalized aircraft map. Returns one of the strings in `classes/0`.

  Military wins over everything, since a military cargo aircraft is far more
  usefully filtered as military.
  """
  def classify(%{"military" => true}), do: "military"

  def classify(aircraft) when is_map(aircraft) do
    prefix = callsign_prefix(aircraft["flight"])

    cond do
      is_binary(prefix) and MapSet.member?(@cargo_prefixes, prefix) -> "cargo"
      cargo_operator?(aircraft["operator"]) -> "cargo"
      is_binary(prefix) and MapSet.member?(@commercial_prefixes, prefix) -> "commercial"
      commercial_operator?(aircraft["operator"]) -> "commercial"
      true -> "general"
    end
  end

  def classify(_), do: "general"

  @doc """
  Keep only aircraft in the wanted classes.

  A nil or empty list means no filtering, which is what keeps area queries saved
  before this field existed showing everything.
  """
  def filter(list, nil), do: list
  def filter(list, []), do: list

  def filter(list, classes) do
    wanted = MapSet.new(classes, &to_string/1)
    Enum.filter(list, fn ac -> MapSet.member?(wanted, ac["class"] || classify(ac)) end)
  end

  # Scheduled callsigns are three letters then the flight number (UAL558). A
  # registration-style callsign (N800JB) has no such split and returns nil.
  defp callsign_prefix(nil), do: nil

  defp callsign_prefix(flight) when is_binary(flight) do
    case Regex.run(~r/^([A-Z]{3})\d/, String.upcase(String.trim(flight))) do
      [_, prefix] -> prefix
      _ -> nil
    end
  end

  defp callsign_prefix(_), do: nil

  defp cargo_operator?(nil), do: false

  defp cargo_operator?(operator) when is_binary(operator) do
    upcased = String.upcase(operator)
    Enum.any?(@cargo_keywords, &String.contains?(upcased, &1))
  end

  defp cargo_operator?(_), do: false

  defp commercial_operator?(nil), do: false

  defp commercial_operator?(operator) when is_binary(operator) do
    upcased = String.upcase(operator)
    Enum.any?(@commercial_keywords, &String.contains?(upcased, &1))
  end

  defp commercial_operator?(_), do: false
end
