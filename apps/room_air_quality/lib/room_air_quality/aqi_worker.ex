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

  # Public
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

  def query_place(id, query) do
    Storage.get_current_information_for_aqi(id, query.foci_id)
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
    |> String.to_integer()
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
    datetime = NaiveDateTime.local_now()
    Logger.info("AQI::#{id} writing bundle")

    case type do
      :hourly ->
        as_csv =
          result.body
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
              :reporting_units,
              :value,
              :data_source
            ],
            separator: ?|
          )
          |> Stream.map(fn {:ok, data} ->
            RoomSanctum.Storage.change_hourly_data(
              %RoomSanctum.Storage.AirNow.HourlyData{},
              data
              |> Map.put(:source_id, id)
              |> Map.put(:valid_date, data.valid_date |> Timex.parse!("%m/%d/%y", :strftime))
            )
            |> Map.put(:inserted_at, datetime)
            |> Map.put(:updated_at, datetime)
          end)
          |> Stream.map(fn x ->
            Repo.insert(
              x,
              on_conflict: {:replace_all_except, [:id]},
              conflict_target: [:source_id, :site_name, :parameter_name]
            )
          end)
          |> Enum.to_list()

      :sites ->
        as_csv =
          result.body
          |> String.split("\r\n")
          |> List.delete_at(0)
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
          |> Enum.to_list()
          |> Enum.map(fn {:ok, x} -> x end)
          |> Enum.group_by(fn x -> x.aqsid end)
          |> Enum.map(fn {k, v} ->
            p = v |> Enum.map(fn q -> q.parameter end)
            f = v |> List.first()
            f |> Map.put(:parameters, p)
          end)
          |> Enum.map(fn data ->
            point = %Geo.Point{
              coordinates:
                {data.latitude |> String.to_float(), data.longitude |> String.to_float()},
              srid: 4326
            }

            RoomSanctum.Storage.change_monitoring_site(
              %RoomSanctum.Storage.AirNow.MonitoringSite{},
              data
              |> Map.put(:source_id, id)
              |> Map.put(:point, point)
              |> Map.put(:gmt_offset, data.gmt_offset |> String.to_float() |> Kernel.trunc())
            )
            |> Map.put(:inserted_at, datetime)
            |> Map.put(:updated_at, datetime)
          end)
          |> Enum.map(fn x ->
            Repo.insert(
              x,
              on_conflict: {:replace_all_except, [:id]},
              conflict_target: [:source_id, :station_id]
            )
          end)

      :hourly_obs ->
        as_csv =
          result.body
          |> String.split("\r\n")
          |> List.delete_at(0)
          |> Enum.filter(fn x -> x != "" end)
          |> CSV.decode(
            headers: [
              :aqsid,
              :site_name,
              :status,
              :epa_region,
              :lat,
              :lon,
              :elevation,
              :gmt_offset,
              :country_code,
              :state_name,
              :valid_date,
              :valid_time,
              :data_source,
              :reporting_areas,
              :ozone_aqi,
              :pm10_aqi,
              :pm25_aqi,
              :no2_aqi,
              :ozone_measured,
              :pm10_measured,
              :pm25_measured,
              :no2_measured,
              :no2,
              :no2_unit,
              :co,
              :co_unit,
              :pm25,
              :pm25_unit,
              :so2,
              :so2_unit,
              :ozone,
              :ozone_unit,
              :pm10,
              :pm10_unit
            ]
          )
          |> Enum.to_list()
          |> Enum.map(fn {:ok, x} -> x end)
          |> Enum.map(fn data ->
            point = %Geo.Point{
              coordinates: {data.lat |> String.to_float(), data.lon |> String.to_float()},
              srid: 4326
            }

            {offset, _} = data.gmt_offset |> Float.parse()

            RoomSanctum.Storage.change_hourly_obs_data(
              %RoomSanctum.Storage.AirNow.HourlyObsData{},
              data
              |> Map.put(:source_id, id)
              |> Map.put(:point, point)
              |> Map.put(:gmt_offset, offset)
              |> Map.put(
                :reporting_areas,
                data |> Map.get(:reporting_areas, "") |> String.split("|")
              )
              |> Map.put(
                :valid_date,
                data.valid_date |> Timex.parse!("%m/%d/%Y", :strftime) |> NaiveDateTime.to_date()
              )
              |> Map.put(
                :valid_time,
                data.valid_time |> Timex.parse!("%H:%M", :strftime) |> NaiveDateTime.to_time()
              )
            )
            |> Map.put(:inserted_at, datetime)
            |> Map.put(:updated_at, datetime)
          end)
          |> Enum.map(fn x ->
            Repo.insert(
              x,
              on_conflict: {:replace_all_except, [:id]},
              conflict_target: [:source_id, :aqsid]
            )
          end)
    end
  end

  defp build_todays_url(ts \\ DateTime.utc_now()) do
    sh =
      ts
      |> DateTime.add(-1 * 60 * 60, :second)

    file_str = sh |> Timex.format!("%Y%m%d%H", :strftime)

    "https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/today/HourlyData_#{file_str}.dat"
  end

  defp build_obs_url(ts \\ DateTime.utc_now()) do
    sh = ts |> DateTime.add(-2 * 60 * 60, :second)
    file_str = sh |> Timex.format!("%Y%m%d%H", :strftime)
    date_str = sh |> Timex.format!("%Y%m%d", :strftime)

    "https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/#{sh.year}/#{date_str}/HourlyAQObs_#{file_str}.dat"
  end

  def handle_cast(:update_static, state) do
    Logger.info("AQI::#{state.id} updating data")
    cfg = Configuration.get_source!(state.id)

    bcast(state.id, :downloading, 1, 10)
    #    case HTTPoison.get(build_todays_url()) do
    #      {:ok, result} ->
    #        write_data(result, :hourly, state.id)
    #        {:noreply, state}
    #
    #      {:error, info} ->
    #        Logger.info(info.reason)
    #        {:noreply, state}
    #    end

    case HTTPoison.get(build_obs_url()) do
      {:ok, result} ->
        write_data(result, :hourly_obs, state.id)
        {:noreply, state}

      {:error, info} ->
        Logger.info(info.reason)
        {:noreply, state}
    end

    #    case HTTPoison.get(@monitoring_site_url) do
    #      {:ok, result} ->
    #        write_data(result, :sites, state.id)
    #        {:noreply, state}
    #
    #      {:error, info} ->
    #        Logger.info(info.reason)
    #        {:noreply, state}
    #    end
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
