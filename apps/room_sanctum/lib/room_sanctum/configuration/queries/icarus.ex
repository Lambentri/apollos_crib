defmodule RoomSanctum.Configuration.Queries.Icarus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Two shapes of aircraft query share one embed, because Keryx and the LiveViews
  dispatch on the *source* type rather than the query type.

    * `:area` -- everything overhead a Foci, the flight-wall view.
    * `:flight` -- one specific flight instance, tracked until it lands.

  Flight mode needs no schedule API: the scheduled arrival is on the ticket, so
  the user supplies it and "early / on time / delayed" is arithmetic against the
  live ADS-B ETA.
  """

  embedded_schema do
    field :mode, Ecto.Enum, values: [:area, :flight], default: :area

    # :area
    field :foci_id, :integer
    field :dist, :integer, default: 25
    field :alt_min, :integer
    field :alt_max, :integer
    # Empty means no filtering, so area queries saved before this field existed
    # keep showing everything.
    field :classes, {:array, :string}, default: []

    # :flight
    field :flight_number, :string
    field :dest, :string
    # Naive on purpose: this is the time printed on the ticket, which is local
    # to the destination airport. Casting it as :utc_datetime silently relabels
    # the user's local time as UTC and throws the delay off by the offset.
    field :sched_arrival, :naive_datetime
    field :sched_departure, :naive_datetime
    field :curb_minutes, :integer, default: 20
  end

  def changeset(source, params) do
    source
    |> cast(params, [
      :mode,
      :foci_id,
      :dist,
      :alt_min,
      :alt_max,
      :classes,
      :flight_number,
      :dest,
      :sched_arrival,
      :sched_departure,
      :curb_minutes
    ])
    |> validate_required([:mode])
    |> validate_mode()
  end

  defp validate_mode(changeset) do
    case get_field(changeset, :mode) do
      :flight -> validate_flight(changeset)
      _ -> validate_area(changeset)
    end
  end

  defp validate_area(changeset) do
    changeset
    |> validate_required([:foci_id, :dist])
    # adsb.fi rejects anything over 250 NM outright.
    |> validate_number(:dist, greater_than_or_equal_to: 1, less_than_or_equal_to: 250)
    |> validate_number(:alt_min, greater_than_or_equal_to: 0)
    |> validate_number(:alt_max, greater_than_or_equal_to: 0)
    |> validate_subset(:classes, RoomIcarus.Classify.classes())
    |> validate_altitude_band()
  end

  defp validate_flight(changeset) do
    changeset
    |> validate_required([:flight_number, :dest, :sched_arrival])
    |> validate_number(:curb_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 180)
    |> validate_callsign()
    |> validate_dest()
  end

  defp validate_altitude_band(changeset) do
    min_alt = get_field(changeset, :alt_min)
    max_alt = get_field(changeset, :alt_max)

    if is_integer(min_alt) and is_integer(max_alt) and min_alt > max_alt do
      add_error(changeset, :alt_min, "must be below the altitude ceiling")
    else
      changeset
    end
  end

  # Catch a bad airline prefix at save time rather than letting the watch sit
  # there quietly matching nothing.
  defp validate_callsign(changeset) do
    case get_field(changeset, :flight_number) do
      nil ->
        changeset

      number ->
        if RoomIcarus.Airlines.callsign(number) do
          changeset
        else
          add_error(
            changeset,
            :flight_number,
            "unrecognised airline - use the ICAO callsign directly (e.g. UAL558)"
          )
        end
    end
  end

  defp validate_dest(changeset) do
    case get_field(changeset, :dest) do
      nil ->
        changeset

      code ->
        if RoomIcarus.Airports.get(code) do
          changeset
        else
          add_error(changeset, :dest, "unknown airport code")
        end
    end
  end
end
