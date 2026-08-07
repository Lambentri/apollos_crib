defmodule RoomIcarus.Flight do
  @moduledoc """
  Tracking one flight instance from "not up yet" through to wheels down.

  ## Why this works without a schedule API

  adsb.fi knows nothing about schedules -- only what is transmitting right now.
  But for a pickup the scheduled arrival is on the ticket, so the user supplies
  it and delay becomes arithmetic: live ETA minus scheduled arrival.

  ## Identity

  Callsigns repeat daily, so matching on `UAL558` alone would happily follow
  whichever instance happens to be airborne. Instead, the first sighting inside
  the watch window latches the aircraft's **ICAO hex** -- burned into the
  airframe, never reused -- and everything after that follows the hex. A tail
  swap before departure resolves itself because the latch happens once the
  aircraft is actually flying.

  A sighting is only accepted if its ETA lands within `@eta_sanity_hours` of the
  scheduled arrival, which is what keeps an ultra-long-haul previous-day
  instance from being latched by mistake.
  """

  alias RoomIcarus.Airports

  @endpoint "https://opendata.adsb.fi/api/v2"

  # Open the window well before arrival so a flight that departs early is still
  # caught, and hold it open afterwards to ride out long delays.
  @window_before_hours 14
  @window_after_hours 12

  # A candidate whose ETA is wildly inconsistent with the ticket is a different
  # instance of the same flight number.
  @eta_sanity_hours 8

  # Wheels-down: the feed reports "ground" for surface aircraft, but a brief
  # ground report during taxi-out would otherwise look like an arrival, so the
  # aircraft also has to have been seen airborne first.
  @landing_speed_kt 40

  # Coverage is patchy over oceans; do not call a disappearance a landing until
  # the aircraft has been missing this long.
  @lost_after_minutes 45

  defstruct [:state, :hex, :registration, :aircraft_type, :eta, :position, :landed_at, :seen_at]

  @doc """
  Advance a watch by one poll.

  Returns a map of attributes to persist. Pure apart from the HTTP fetch, so the
  transitions can be exercised directly in tests via `step/3`.
  """
  def poll(watch, now \\ DateTime.utc_now()) do
    cond do
      watch.state in ["landed", "expired"] ->
        %{}

      not in_window?(watch, now) ->
        if DateTime.compare(now, window_close(watch)) == :gt do
          %{state: "expired"}
        else
          %{}
        end

      true ->
        case fetch(watch) do
          {:ok, candidates} -> step(watch, candidates, now)
          :error -> maybe_lost(watch, now)
        end
    end
  end

  @doc """
  The state transition itself, given the aircraft the feed returned.

  Split out from `poll/2` so it can be driven with fixture data.
  """
  def step(watch, candidates, now) do
    case select(watch, candidates, now) do
      nil -> maybe_lost(watch, now)
      aircraft -> observe(watch, aircraft, now)
    end
  end

  # Once latched, only ever follow the hex. Before that, take the first
  # candidate whose ETA is consistent with the ticket.
  defp select(%{hex: hex}, candidates, _now) when is_binary(hex) do
    Enum.find(candidates, &(&1["hex"] == hex))
  end

  defp select(watch, candidates, now) do
    Enum.find(candidates, fn ac ->
      case eta_for(watch, ac, now) do
        nil -> false
        eta -> abs(DateTime.diff(eta, watch.sched_arrival, :second)) <= @eta_sanity_hours * 3600
      end
    end)
  end

  defp observe(watch, aircraft, now) do
    eta = eta_for(watch, aircraft, now)

    base = %{
      hex: aircraft["hex"],
      registration: aircraft["registration"] || watch.registration,
      aircraft_type: aircraft["type"] || watch.aircraft_type,
      last_seen_at: now,
      last_position: aircraft,
      eta: eta
    }

    base = if is_nil(watch.first_seen_at), do: Map.put(base, :first_seen_at, now), else: base

    cond do
      landed?(watch, aircraft) ->
        base |> Map.merge(%{state: "landed", landed_at: now, eta: nil})

      true ->
        Map.put(base, :state, "enroute")
    end
  end

  # Only call it a landing if we have seen this aircraft airborne at some point,
  # so a watch that starts while the aircraft is still at the origin gate does
  # not immediately report an arrival.
  defp landed?(watch, aircraft) do
    airborne_before? = watch.state == "enroute"
    on_ground? = aircraft["alt_baro"] == "ground"
    slow? = is_number(aircraft["gs"]) and aircraft["gs"] <= @landing_speed_kt

    airborne_before? and on_ground? and slow?
  end

  # Disappearing is not landing -- but if it vanishes near the destination after
  # having been airborne, and stays gone, it almost certainly arrived.
  defp maybe_lost(watch, now) do
    cond do
      watch.state != "enroute" ->
        %{}

      is_nil(watch.last_seen_at) ->
        %{}

      DateTime.diff(now, watch.last_seen_at, :second) < @lost_after_minutes * 60 ->
        %{}

      near_destination?(watch) ->
        %{state: "landed", landed_at: watch.last_seen_at, eta: nil}

      true ->
        %{}
    end
  end

  defp near_destination?(%{last_position: pos, dest: dest}) when is_map(pos) do
    with {lat, lon} <- position_of(pos),
         {dlat, dlon} <- Airports.coordinates(dest) do
      Airports.distance_nm({lat, lon}, {dlat, dlon}) <= 50
    else
      _ -> false
    end
  end

  defp near_destination?(_), do: false

  defp position_of(pos) do
    lat = pos["lat"] || pos[:lat]
    lon = pos["lon"] || pos[:lon]
    if is_number(lat) and is_number(lon), do: {lat, lon}, else: nil
  end

  @doc """
  Estimated touchdown from current position, ground speed, and the great-circle
  distance to the destination.

  Deliberately naive: it assumes a direct track and ignores approach vectors,
  holding, and winds. Good to roughly ten minutes a couple of hours out, and
  much tighter on descent -- fine for deciding when to leave the house.
  """
  def eta_for(watch, aircraft, now) do
    with {lat, lon} <- position_of(aircraft),
         dest when not is_nil(dest) <- Airports.coordinates(watch.dest),
         gs when is_number(gs) and gs > 40 <- aircraft["gs"] do
      distance = Airports.distance_nm({lat, lon}, dest)
      DateTime.add(now, round(distance / gs * 3600), :second)
    else
      _ -> nil
    end
  end

  @doc "Minutes early (negative) or late (positive) against the ticket."
  def delay_minutes(%{eta: nil}), do: nil

  def delay_minutes(%{eta: eta, sched_arrival: sched}) when not is_nil(sched) do
    div(DateTime.diff(eta, sched, :second), 60)
  end

  def delay_minutes(_), do: nil

  def window_open(watch), do: DateTime.add(watch.sched_arrival, -@window_before_hours * 3600)
  def window_close(watch), do: DateTime.add(watch.sched_arrival, @window_after_hours * 3600)

  defp in_window?(watch, now) do
    DateTime.compare(now, window_open(watch)) != :lt and
      DateTime.compare(now, window_close(watch)) != :gt
  end

  defp fetch(watch) do
    url = "#{@endpoint}/callsign/#{watch.callsign}"

    case HTTPoison.get(url, [{"Accept", "application/json"}], recv_timeout: 15_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, %{"ac" => ac}} when is_list(ac) ->
            {:ok, Enum.map(ac, &RoomIcarus.Worker.normalize_aircraft/1)}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end
end
