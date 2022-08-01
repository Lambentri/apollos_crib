defmodule RoomEphem.Worker do
  @moduledoc false
#  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  @ttl :timer.hours(8)

  @decorate cacheable(cache: RoomZeus.Cache, opts: [ttl: @ttl])
  def query_ephem(_name, query) do
    foci = Configuration.get_foci!(query.foci_id)
    {lat, lon} = foci.place.coordinates
    tz = WhereTZ.lookup(lat, lon)
    {:ok, sunrise} = Solarex.Sun.rise(Date.utc_today(), lat, lon)
    {:ok, sunset} = Solarex.Sun.set(Date.utc_today(), lat, lon)
    phase = Solarex.Moon.phase(Date.utc_today())

    [
      %{
        period: :sunrise,
        result:
          sunrise
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.shift_zone!(tz)
          |> DateTime.to_time()
      },
      %{
        period: :sunset,
        result:
          sunset
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.shift_zone!(tz)
          |> DateTime.to_time()
      },
      %{period: :phase, result: phase},
      %{name: foci.name}
    ]
  end
end
