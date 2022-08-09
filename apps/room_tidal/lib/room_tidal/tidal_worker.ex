defmodule RoomTidal.Worker do
  @moduledoc false
  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  @ttl :timer.hours(4)

  @registry :zeus
  @root_url "https://tidesandcurrents.noaa.gov/api/datagetter?date=today&product=predictions&datum=mllw&interval=hilo&format=json&units=metric&time_zone=lst_ldt&station="

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("tidal" <> opts[:name]))
  end

  @decorate cacheable(cache: RoomZeus.Cache, opts: [ttl: @ttl])
  def query_tides(name, query) do
    "tidal#{name}"
    |> via_tuple()
    |> GenServer.call({:query_tides, query})
  end

  def init(opts) do
    {:ok, %{id: opts[:name]}}
  end

  def handle_call({:query_tides, query}, _from, state) do
    case HTTPoison.get(@root_url <> query.station_id, [], follow_redirect: true) do
      {:ok, result} ->
        decoded = result.body |> Poison.decode!(keys: :atoms)
        {:reply, decoded.predictions, state}

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
