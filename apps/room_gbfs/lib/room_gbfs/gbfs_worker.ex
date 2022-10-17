defmodule RoomGbfs.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gbfs" <> opts[:name]))
  end

  def init(opts) do
    {:ok, %{id: opts[:name], inst: nil}}
  end

  # public
  def refresh_db_cfg(name) do
    "gbfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def update_static_data(name) do
    "gbfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static)
  end

  def update_realtime_data(name) do
    "gbfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_realtime)
  end

  def query_stop(id, query) do
    [Storage.get_current_information_for_bikestop(id, query.stop_id)]
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(:refresh_db_cfg, state) do
    IO.puts("rerere")
    {:noreply, state |> Map.put(:inst, nil)}
  end

  defp bcast(id, file, complete, total) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gbfs", {:gbfs, id, file, complete, total})
  end

  defp bcast(id, file, message) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gbfs", {:gbfs, id, file, message})
  end

  defp intify(val) when is_binary(val) do
    val |> String.to_integer()
  end

  defp intify(val) do
    val
  end

  defp inj_iddt(map, id, dt) do
    map
    |> Map.put(:source_id, id |> intify)
    |> Map.put(:inserted_at, dt)
    |> Map.put(:updated_at, dt)
  end

  defp write_data(url, type, id) do
    dt = NaiveDateTime.local_now()
    Logger.info("GBFS::#{id} retrieving #{url}")

    case HTTPoison.get(url) do
      {:ok, result} ->
        case result.body
             |> Poison.decode(keys: :atoms) do
          {:ok, json} ->
            case type do
              :sys_info ->
                Repo.insert(
                  RoomSanctum.Storage.change_sys_info(
                    %RoomSanctum.Storage.GBFS.V1.SysInfo{},
                    json.data |> Map.put(:source_id, id |> intify)
                  ),
                  on_conflict: {:replace_all_except, [:id]},
                  conflict_target: [:source_id, :system_id]
                )

              :stat_info ->
                data =
                  json.data.stations
                  |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
                  |> Enum.map(fn x ->
                    point = %Geo.Point{coordinates: {x.lon, x.lat}, srid: 4326}
                    x |> Map.put(:place, point)
                  end)
                  |> Enum.map(fn x ->
                    RoomSanctum.Storage.change_station_info(
                      %RoomSanctum.Storage.GBFS.V1.StationInfo{},
                      x
                    ).changes
                    |> inj_iddt(id, dt)
                  end)

                Repo.insert_all(
                  RoomSanctum.Storage.GBFS.V1.StationInfo,
                  data,
                  on_conflict: {:replace_all_except, [:id]},
                  conflict_target: [:source_id, :station_id]
                )

              :stat_status ->
                data =
                  json.data.stations
                  |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
                  |> Enum.map(fn x ->
                    RoomSanctum.Storage.change_station_status(
                      %RoomSanctum.Storage.GBFS.V1.StationStatus{},
                      x
                    ).changes
                    |> inj_iddt(id, dt)
                  end)

                Repo.insert_all(
                  RoomSanctum.Storage.GBFS.V1.StationStatus,
                  data,
                  on_conflict: {:replace_all_except, [:id]},
                  conflict_target: [:source_id, :station_id]
                )

              :free_bike ->
                :ok

              :sys_hours ->
                :ok

              :sys_cal ->
                :ok

              :sys_regions ->
                :ok

              :sys_alerts ->
                data =
                  json.data.alerts
                  |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
                  |> Enum.map(fn x ->
                    RoomSanctum.Storage.change_gbfs_alert(%RoomSanctum.Storage.GBFS.V1.Alert{}, x).changes
                    |> inj_iddt(id, dt)
                  end)

                Repo.insert_all(
                  RoomSanctum.Storage.GBFS.V1.Alert,
                  data,
                  on_conflict: {:replace_all_except, [:id]},
                  conflict_target: [:source_id, :alert_id]
                )
            end

          {:error, info} ->
            Logger.info(info.reason)
        end

      {:error, info} ->
        Logger.info(info.reason)
    end
  end

  def handle_cast(:update_static, state) do
    Logger.info("GBFS::#{state.id} updating static info ")
    cfg = Configuration.get_source!(state.id)

    bcast(state.id, :downloading, 1, 10)

    case HTTPoison.get(cfg.config.url) do
      {:ok, result} ->
        json_body =
          result.body
          |> Poison.decode!()

        if json_body["data"]
           |> Map.has_key?(cfg.config.lang) do
          bcast(state.id, :parsing, 2, 10)

          json_body["data"][cfg.config.lang]["feeds"]
          |> Enum.map(fn %{"name" => name, "url" => url} ->
            case name do
              "system_information" ->
                write_data(url, :sys_info, state.id)
                bcast(state.id, :system_information, 3, 10)

              "station_information" ->
                write_data(url, :stat_info, state.id)
                bcast(state.id, :system_information, 4, 10)

              "station_status" ->
                write_data(url, :stat_status, state.id)
                bcast(state.id, :system_information, 5, 10)

              "free_bike_status" ->
                write_data(url, :free_bike, state.id)
                bcast(state.id, :system_information, 6, 10)

              "system_hours" ->
                write_data(url, :sys_hours, state.id)
                bcast(state.id, :system_information, 7, 10)

              "system_calendar" ->
                write_data(url, :sys_cal, state.id)
                bcast(state.id, :system_information, 8, 10)

              "system_regions" ->
                write_data(url, :sys_regions, state.id)
                bcast(state.id, :system_information, 9, 10)

              "system_alerts" ->
                write_data(url, :sys_alerts, state.id)
                bcast(state.id, :system_information, 10, 10)
            end
          end)

          {:noreply, state}
        else
          bcast(
            state.id,
            :language_error,
            "Invalid Language Selected, available #{json_body["data"] |> Map.keys() |> Enum.join(", ")}, selected: #{cfg.config.lang}"
          )

          {:noreply, state}
        end

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
