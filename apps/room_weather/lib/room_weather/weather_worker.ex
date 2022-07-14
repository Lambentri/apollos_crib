defmodule RoomWeather.Worker do
  @moduledoc false
  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  @ttl :timer.hours(1)

  @registry :zeus
  @root_url "https://api.openweathermap.org/data/2.5/weather"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("weather" <> opts[:name]))
  end

  @decorate cacheable(cache: RoomZeus.Cache, opts: [ttl: @ttl])
  def query_weather(name, query) do
    "weather#{name}" |> via_tuple() |> GenServer.call({:query_weather, query}) |> IO.inspect()
  end

  def init(opts) do
    c = Configuration.get_source!(opts[:name])
    {:ok, %{id: opts[:name], src: c}}
  end

  def handle_call({:query_weather, query}, _from, state) do
    foci = Configuration.get_foci!(query.foci_id)
    {lat, lon} = foci.place.coordinates

    case HTTPoison.get(@root_url, [],
           follow_redirect: true,
           params: %{
             lon: lon,
             lat: lat,
             appid: state.src.config.api_key,
             units: state.src.config.units
           }
         ) do
      {:ok, result} ->
        decoded = result.body |> Poison.decode!(keys: :atoms)
        {:reply, [decoded], state}

      {:error, reason} ->
        Logger.info("Failed to retrieve data from NOAA Tides due to #{reason.reason}")
        {:reply, [], state}
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, [:ok], state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
