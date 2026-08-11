defmodule RoomAirQuality.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus

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

  # A station id names one monitor; a foci means "whatever is nearest". The
  # station wins when both are set, and falls back to the foci if that monitor
  # has stopped reporting rather than showing nothing.
  def query_place(id, query) do
    aqsid = Map.get(query, :aqsid)
    foci_id = Map.get(query, :foci_id)

    cond do
      is_binary(aqsid) and aqsid != "" ->
        case Storage.get_aqi_station(id, aqsid) do
          [] when not is_nil(foci_id) -> Storage.get_current_information_for_aqi(id, foci_id)
          [] -> []
          station -> station
        end

      not is_nil(foci_id) ->
        Storage.get_current_information_for_aqi(id, foci_id)

      true ->
        []
    end
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(60 * 60),
      run: fn -> RoomAirQuality.Worker.update_static_data(opts[:name]) end,
      initial_delay: :timer.seconds(30)
    )

    {:ok, %{id: opts[:name]}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  defp bcast(id, file, complete, total) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "aqi", {:aqi, id, file, complete, total})
  end

  defp intify(val) when val == "", do: nil
  defp intify(val) when is_binary(val), do: val |> String.to_integer()
  defp intify(val) when is_float(val), do: val |> Kernel.trunc()
  defp intify(val), do: val

  defp parse_float(""), do: nil
  defp parse_float(nil), do: nil

  defp parse_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_float(f) when is_float(f), do: f
  defp parse_float(_), do: nil

  # AirNow leaves unmeasured pollutant fields as empty strings ("").
  # Ecto's :float cast rejects "" (changeset becomes invalid → row silently dropped).
  # Normalize all blanks to nil before building the changeset.
  defp normalize_blanks(data) do
    data
    |> Enum.map(fn {k, v} -> {k, if(v == "", do: nil, else: v)} end)
    |> Map.new()
  end

  defp write_data(result, type, id) do
    datetime = NaiveDateTime.local_now()
    Logger.info("AQI::#{id} writing bundle #{type}")

    case type do
      :hourly ->
        result.body
        |> String.split(~r/\r?\n/)
        |> Enum.filter(fn x -> x != "" end)
        |> Enum.map(&(&1 <> "\n"))
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
        result.body
        |> String.split(~r/\r?\n/)
        |> List.delete_at(0)
        |> Enum.filter(fn x -> x != "" end)
        # The :csv library expects each stream element to end with a newline;
        # without it, consecutive lines are interpreted as quote-escaped
        # continuations and the entire file collapses into a single row.
        |> Enum.map(&(&1 <> "\n"))
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
        |> Enum.map(fn {_k, v} ->
          p = v |> Enum.map(fn q -> q.parameter end)
          f = v |> List.first()
          f |> Map.put(:parameters, p)
        end)
        |> Enum.map(fn data ->
          # {lon, lat}, as PostGIS expects -- st_distance against a foci
          # compares the two directly.
          point = %Geo.Point{
            coordinates:
              {data.longitude |> String.to_float(), data.latitude |> String.to_float()},
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
        # Column order matches AirNow's current HourlyAQObs CSV header (verified live).
        # Positions 23-34 reorder: PM25, OZONE, NO2, CO, SO2, PM10 (each followed by its _Unit).
        result.body
        |> String.split(~r/\r?\n/)
        |> List.delete_at(0)
        |> Enum.filter(fn x -> x != "" end)
        # The :csv library expects each stream element to end with a newline;
        # without it, consecutive lines are interpreted as quote-escaped
        # continuations and the entire file collapses into a single row.
        |> Enum.map(&(&1 <> "\n"))
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
            :pm25,
            :pm25_unit,
            :ozone,
            :ozone_unit,
            :no2,
            :no2_unit,
            :co,
            :co_unit,
            :so2,
            :so2_unit,
            :pm10,
            :pm10_unit
          ]
        )
        |> Enum.to_list()
        |> Enum.map(fn {:ok, x} -> x end)
        |> Enum.map(&normalize_blanks/1)
        |> Enum.map(fn data ->
          lat = parse_float(data.lat)
          lon = parse_float(data.lon)

          point =
            if lat && lon do
              %Geo.Point{coordinates: {lon, lat}, srid: 4326}
            end

          RoomSanctum.Storage.change_hourly_obs_data(
            %RoomSanctum.Storage.AirNow.HourlyObsData{},
            data
            |> Map.put(:source_id, id)
            |> Map.put(:point, point)
            |> Map.put(:lat, lat)
            |> Map.put(:lon, lon)
            |> Map.put(:elevation, parse_float(data[:elevation]))
            |> Map.put(:gmt_offset, parse_float(data[:gmt_offset]))
            |> Map.put(
              :reporting_areas,
              (data[:reporting_areas] || "") |> String.split("|")
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
          |> Map.put(:ozone_aqi, data.ozone_aqi |> intify)
          |> Map.put(:pm10_aqi, data.pm10_aqi |> intify)
          |> Map.put(:pm25_aqi, data.pm25_aqi |> intify)
          |> Map.put(:no2_aqi, data.no2_aqi |> intify)
        end)
        |> Enum.reduce({0, 0, []}, fn cs, {ok, fail, sample_errs} ->
          case Repo.insert(cs,
                 on_conflict: {:replace_all_except, [:id]},
                 conflict_target: [:source_id, :aqsid]
               ) do
            {:ok, _} ->
              {ok + 1, fail, sample_errs}

            {:error, bad} ->
              new_sample =
                if length(sample_errs) < 3 do
                  [{cs.changes[:aqsid] || cs.data.aqsid, bad.errors} | sample_errs]
                else
                  sample_errs
                end

              {ok, fail + 1, new_sample}
          end
        end)
        |> case do
          {ok, 0, _} ->
            Logger.info("AQI::#{id} inserted #{ok} rows")

          {ok, fail, sample} ->
            Logger.warning(
              "AQI::#{id} inserted #{ok} rows, #{fail} failed. First failures: #{inspect(sample)}"
            )
        end
    end

    Logger.info("AQI::#{id} completed writing bundle")
  end

  #  defp build_todays_url(ts \\ DateTime.utc_now()) do
  #    sh =
  #      ts
  #      |> DateTime.add(-1 * 60 * 60, :second)
  #
  #    file_str = sh |> Timex.format!("%Y%m%d%H", :strftime)
  #
  #    "https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/today/HourlyData_#{file_str}.dat"
  #  end

  defp build_obs_url(hours_ago, ts \\ DateTime.utc_now()) do
    sh = ts |> DateTime.add(-hours_ago * 60 * 60, :second)
    file_str = sh |> Timex.format!("%Y%m%d%H", :strftime)
    date_str = sh |> Timex.format!("%Y%m%d", :strftime)
    "https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/#{sh.year}/#{date_str}/HourlyAQObs_#{file_str}.dat"
  end

  # AirNow publishes HourlyAQObs files with variable lag (typically ~1-3h).
  # Walk back from 1h to 6h and use the first 200 we find.
  defp fetch_latest_obs(id) do
    Enum.reduce_while(1..6, nil, fn hours_ago, _acc ->
      url = build_obs_url(hours_ago)

      case HTTPoison.get(url) do
        {:ok, %{status_code: 200} = result} ->
          Logger.info("AQI::#{id} fetched #{url}")
          {:halt, {:ok, result}}

        {:ok, %{status_code: code}} ->
          Logger.debug("AQI::#{id} #{code} on #{url}, trying older hour")
          {:cont, nil}

        {:error, info} ->
          Logger.warning("AQI::#{id} HTTP error on #{url}: #{inspect(info.reason)}")
          {:cont, nil}
      end
    end)
    |> case do
      {:ok, _} = ok ->
        ok

      _ ->
        Logger.warning("AQI::#{id} no AirNow file available in last 6 hours")
        :error
    end
  end

  def handle_cast(:refresh_db_cfg, state) do
    IO.puts("rerere")
    {:noreply, state}
  end

  def handle_cast(:update_static, state) do
    Logger.info("AQI::#{state.id} updating data")
    bcast(state.id, :downloading, 1, 10)

    case fetch_latest_obs(state.id) do
      {:ok, result} -> write_data(result, :hourly_obs, state.id)
      :error -> :ok
    end

    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
