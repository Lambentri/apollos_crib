defmodule RoomCronos.Worker do
  @moduledoc false
  #  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  #  @ttl :timer.minutes(1)
  #
  #  @decorate cacheable(cache: RoomZeus.Cache, opts: [ttl: @ttl])
  def query_cronos(name, query) do
    q = Configuration.get_query!(name)
    foci = Configuration.get_foci!(query.foci_id)
    {lat, lon} = foci.place.coordinates
    tz = WhereTZ.lookup(lat, lon)
    now = DateTime.now!(tz)

    result =
      case query.period do
        :minute -> (now.minute + query.offset) |> rem(query.modulo) == 0
        :hour -> (now.hour + query.offset) |> rem(query.modulo) == 0
        :day -> (now.day + query.offset) |> rem(query.modulo) == 0
        :week -> :ok
        :month -> (now.month + query.offset) |> rem(query.modulo) == 0
      end

    [%{name: q.name, value: result}]
  end
end
