defmodule RoomEphem.Worker do
  @moduledoc false
  #  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  @ttl :timer.hours(8)

  defp normalize_ll(val) do
    cond do
      val < -180 -> val + 360
      true -> val
    end
  end

  # ── Moon rise/set calculation ────────────────────────────────────────────────
  # Low-precision algorithm (~5–15 min accuracy) based on Jean Meeus,
  # "Astronomical Algorithms", low-precision moon position formulas.

  defp jd_from_date(%Date{year: y, month: m, day: d}) do
    a  = div(14 - m, 12)
    yy = y + 4800 - a
    mm = m + 12 * a - 3
    (d + div(153 * mm + 2, 5) + 365 * yy + div(yy, 4) - div(yy, 100) + div(yy, 400) - 32045) - 0.5
  end

  defp sin_d(deg), do: :math.sin(deg * :math.pi() / 180.0)
  defp cos_d(deg), do: :math.cos(deg * :math.pi() / 180.0)
  defp tan_d(deg), do: :math.tan(deg * :math.pi() / 180.0)
  defp asin_d(x),  do: :math.asin(x) * 180.0 / :math.pi()
  defp atan2_d(y, x), do: :math.atan2(y, x) * 180.0 / :math.pi()

  defp norm_deg(deg) do
    r = :math.fmod(deg, 360.0)
    if r < 0, do: r + 360.0, else: r
  end

  defp norm_hours(h) do
    r = :math.fmod(h, 24.0)
    if r < 0, do: r + 24.0, else: r
  end

  defp moon_ra_dec(jd) do
    d   = jd - 2451545.0
    ll  = norm_deg(218.316 + 13.176396 * d)
    mm  = norm_deg(134.963 + 13.064993 * d)
    ff  = norm_deg(93.272  + 13.229350 * d)
    lon = ll + 6.289 * sin_d(mm)
    lat = 5.128 * sin_d(ff)
    eps = 23.439 - 0.0000004 * d
    ra  = atan2_d(sin_d(lon) * cos_d(eps) - tan_d(lat) * sin_d(eps), cos_d(lon))
    dec = asin_d(sin_d(lat) * cos_d(eps) + cos_d(lat) * sin_d(eps) * sin_d(lon))
    {norm_deg(ra), dec}
  end

  defp gmst_midnight(jd) do
    d = jd - 2451545.0
    t = d / 36525.0
    norm_deg(100.4606184 + 36000.77004 * t + 0.000387933 * t * t)
  end

  # Returns {:ok, rise_ut_hours, set_ut_hours} or {:error, reason}
  defp moon_rise_set_ut(date, lat, lon) do
    jd        = jd_from_date(date)
    {ra, dec} = moon_ra_dec(jd + 0.5)
    gmst      = gmst_midnight(jd)
    lst       = norm_deg(gmst + lon)
    cos_ha    = (sin_d(0.125) - sin_d(lat) * sin_d(dec)) / (cos_d(lat) * cos_d(dec))

    cond do
      cos_ha > 1.0  -> {:error, :circumpolar_below}
      cos_ha < -1.0 -> {:error, :circumpolar_above}
      true ->
        ha      = :math.acos(cos_ha) * 180.0 / :math.pi()
        transit = norm_hours(norm_deg(ra - lst) / 15.0)
        rise    = norm_hours(transit - ha / 15.0)
        set     = norm_hours(transit + ha / 15.0)
        {:ok, rise, set}
    end
  end

  defp ut_to_local_time(date, ut_hours, tz) do
    clamped = max(0.0, min(ut_hours, 23.9999))
    h       = trunc(clamped)
    frac_m  = (clamped - h) * 60.0
    m       = trunc(frac_m)
    s       = trunc((frac_m - m) * 60.0)
    {:ok, ndt} = NaiveDateTime.new(date.year, date.month, date.day, h, m, s)
    ndt |> DateTime.from_naive!("Etc/UTC") |> Timex.Timezone.convert(tz) |> DateTime.to_time()
  end

  # ────────────────────────────────────────────────────────────────────────────

  @decorate cacheable(cache: RoomZeus.Cache, opts: [ttl: @ttl])
  def query_ephem(_name, query) do
    IO.inspect("QEPH")
    foci = Configuration.get_foci!(query.foci_id)
    {lon, lat} = foci.place.coordinates
    lat = normalize_ll(lat)
    lon = normalize_ll(lon)

    tz = WhereTZ.lookup(lat, lon)
    {:ok, sunrise} = Solarex.Sun.rise(Date.utc_today(), lat, lon)
    {:ok, sunset}  = Solarex.Sun.set(Date.utc_today(), lat, lon)
    phase          = Solarex.Moon.phase(Date.utc_today())

    moon_entries =
      case moon_rise_set_ut(Date.utc_today(), lat, lon) do
        {:ok, rise_h, set_h} ->
          [
            %{period: :moonrise, result: ut_to_local_time(Date.utc_today(), rise_h, tz)},
            %{period: :moonset,  result: ut_to_local_time(Date.utc_today(), set_h,  tz)}
          ]
        {:error, _} ->
          []
      end

    [
      %{
        period: :sunrise,
        result:
          sunrise
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.Timezone.convert(tz)
          |> DateTime.to_time()
      },
      %{
        period: :sunset,
        result:
          sunset
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.Timezone.convert(tz)
          |> DateTime.to_time()
      },
      %{period: :phase, result: phase},
      %{name: foci.name}
    ] ++ moon_entries
  end
end