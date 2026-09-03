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
    foci = %{place: Configuration.place_for!(query)}
    {lon, lat} = foci.place.coordinates
    tz = WhereTZ.lookup(lat, lon)
    now = DateTime.now!(tz)

    case mode(query) do
      :countdown -> countdown(q, query, now, tz)
      _ -> modulo(q, query, now)
    end
  end

  defp mode(query) do
    case Map.get(query, :mode) do
      :countdown -> :countdown
      "countdown" -> :countdown
      _ -> :modulo
    end
  end

  defp modulo(q, query, now) do
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

  defp countdown(q, query, now, tz) do
    case RoomCronos.Countdown.compute(query.target, query.annual == true, now, tz) do
      nil ->
        []

      result ->
        [Map.merge(result, %{name: q.name, mode: :countdown})]
    end
  end
end
