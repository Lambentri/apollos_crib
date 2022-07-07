defmodule RoomAirQuality.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus
  @monitoring_site_url "https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/today/Monitoring_Site_Locations_V2.dat"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("aqi" <> opts[:name]))
  end

  def refresh_db_cfg(name) do
    "aqi#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def update_static_data(name) do
    "aqi#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static)
  end

  def update_realtime_data(name) do
    "aqi#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_realtime)
  end


  def init(opts) do
    {:ok, %{id: opts[:name]}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(:refresh_db_cfg, state) do
    IO.puts("rerere")
    {:noreply, state}
  end

  defp bcast(id, file, complete, total) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "aqi", {:aqi, id, file, complete, total})
  end

  defp bcast(id, file, message) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "aqi", {:aqi, id, file, message})
  end

  defp intify(val) when is_binary(val) do
    val
    |> String.to_integer
  end

  defp intify(val) do
    val
  end

  defp inj_iddt(map, id, dt) do
    map
    |> Map.put(
         :source_id,
         id
         |> intify
       )
    |> Map.put(:inserted_at, dt)
    |> Map.put(:updated_at, dt)
  end

  defp write_data(result, type, id) do
    Logger.info("AQI::#{id} parsing bundle")

    case type do
      :hourly -> as_csv = result.body
                          |> String.split("\r\n")
                          |> Enum.filter(fn x -> x != "" end)
                          |> CSV.decode(

                                 headers: [
                                   :valid_date,
                                   :valid_time,
                                   :aqsid,
                                   :site_name,
                                   :gmt_offset,
                                   :parameter_name,
                                   :repoting_units,
                                   :value,
                                   :data_source
                                 ],
                                 separator: ?|

                             )
                          |> Enum.map(fn x -> x end)
                          |> IO.inspect

      :sites -> as_csv = result.body
                         |> String.split("\r\n")
                         |> Enum.filter(fn x -> x != "" end)
                         |> CSV.decode(

                                headers: [
                                  :station_id,
                                  :aqsid,
                                  :full_aqsid,
                                  :parameter,
                                  :monitor_type,

                                  :site_code,
                                  :site_name,
                                  :status,
                                  :agency_id,
                                  :agency_name,

                                  :epa_region,
                                  :latitude,
                                  :longitude,
                                  :elevation,
                                  :gmt_offset,

                                  :country_fips,
                                  :cbsa_id,
                                  :cbsa_name,
                                  :state_aqs_code,
                                  :state_abbreviation,

                                  :county_aqs_code,
                                  :county_name
                                ],
                                separator: ?|

                            )
                            |> Enum.map(fn x -> x end)
                         |> IO.inspect
    end



  end

  defp build_todays_url(ts \\ DateTime.utc_now) do
    sh = ts
         |> DateTime.add(-1 * 60 * 60, :second)
    "https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/today/HourlyData_#{
      sh
      |> Timex.format!("%Y%m%d%H", :strftime)
    }.dat"
  end

  def handle_cast(:update_static, state) do
    Logger.info("AQI::#{state.id} updating data")
    cfg = Configuration.get_source!(state.id)

    bcast(state.id, :downloading, 1, 10)
    case HTTPoison.get(build_todays_url()) do
      {:ok, result} ->
        write_data(result, :hourly, state.id)
        {:noreply, state}

      {:error, info} ->
        Logger.info(info.reason)
        {:noreply, state}
    end
    case HTTPoison.get(@monitoring_site_url) do
      {:ok, result} ->
        write_data(result, :sites, state.id)
        {:noreply, state}

      {:error, info} ->
        Logger.info(info.reason)
        {:noreply, state}
    end
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
