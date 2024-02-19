defmodule RoomGbfs.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus
  @dynamic_refresh_seconds 300

  # 1d
  @static_refresh_seconds 86400
  @static_delay_seconds 600

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gbfs" <> opts[:name]))
  end

  @impl true
  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(@dynamic_refresh_seconds),
      run: fn -> RoomGbfs.Worker.update_realtime_data(opts[:name]) end,
      initial_delay: 100
    )

    Periodic.start_link(
      every: :timer.seconds(@static_refresh_seconds),
      run: fn -> RoomGbfs.Worker.update_static_data(opts[:name]) end,
      initial_delay: :timer.minutes(@static_delay_seconds)
    )

    {:ok, %{id: opts[:name], inst: nil}}
  end

  # public
  def refresh_db_cfg(name) do
    "gbfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def scheduled_static(name) do
    "gbfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:scheduled_static)
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

  defp bcast(id, :disabled) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gbfs", {:gbfs, id, :disabled})
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

              :ebikes_at_stations ->
                data =
                  json.data.stations
                  |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
                  |> Enum.map(fn x ->
                    cs = RoomSanctum.Storage.change_ebikes_at_stations(
                      %RoomSanctum.Storage.GBFS.V1.EbikesAtStations{},
                      x
                    ).changes
                    |> inj_iddt(id, dt)

                    eb = cs.ebikes |> Enum.map(fn eb -> eb |> Ecto.Changeset.apply_changes end)
                    cs |> Map.put(:ebikes, eb)
                  end)

                RoomSanctum.Storage.truncate_ebikes_at_stations(id)
                Repo.insert_all(
                  RoomSanctum.Storage.GBFS.V1.EbikesAtStations,
                  data,
                  on_conflict: {:replace_all_except, [:id]},
                  conflict_target: [:source_id, :station_id]
                )
            end

          {:error, info} ->
            Logger.info(info.reason)
        end

      {:error, info} ->
        Logger.info(info.reason)
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:refresh_db_cfg, state) do
    IO.puts("rerere")
    {:noreply, state |> Map.put(:inst, nil)}
  end

  @impl true
  def handle_cast(:update_static, state) do
    cfg = Configuration.get_source!(state.id)

    case cfg.enabled do
      true ->
        Logger.info("GBFS::#{state.id} updating static info ")
        bcast(state.id, :downloading, 1, 11)

        case HTTPoison.get(cfg.config.url) do
          {:ok, result} ->
            json_body =
              result.body
              |> Poison.decode!()

            if json_body["data"]
               |> Map.has_key?(cfg.config.lang) do
              bcast(state.id, :parsing, 2, 11)

              json_body["data"][cfg.config.lang]["feeds"]
              |> Enum.map(fn %{"name" => name, "url" => url} ->
                case name do
                  "ebikes_at_stations" ->
                    write_data(url, :ebikes_at_stations, state.id)
                    bcast(state.id, :system_information, 3, 11)

                  "system_information" ->
                    write_data(url, :sys_info, state.id)
                    bcast(state.id, :system_information, 4, 11)

                  "station_information" ->
                    write_data(url, :stat_info, state.id)
                    bcast(state.id, :system_information, 5, 11)

                  "station_status" ->
                    write_data(url, :stat_status, state.id)
                    bcast(state.id, :system_information, 6, 11)

                  "free_bike_status" ->
                    write_data(url, :free_bike, state.id)
                    bcast(state.id, :system_information, 7, 11)

                  "system_hours" ->
                    write_data(url, :sys_hours, state.id)
                    bcast(state.id, :system_information, 8, 11)

                  "system_calendar" ->
                    write_data(url, :sys_cal, state.id)
                    bcast(state.id, :system_information, 9, 11)

                  "system_regions" ->
                    write_data(url, :sys_regions, state.id)
                    bcast(state.id, :system_information, 10, 11)

                  "system_alerts" ->
                    write_data(url, :sys_alerts, state.id)
                    bcast(state.id, :system_information, 11, 11)

                  otherwise ->
                    Logger.info("GBFS::#{state.id} System has unhandled file #{otherwise}")
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

      false ->
        bcast(state.id, :disabled)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:update_realtime, state) do
    cfg = Configuration.get_source!(state.id)

    case cfg.enabled do
      true ->
        Logger.info("GBFS::#{state.id} updating realtime info ")
        bcast(state.id, :downloading, 1, 4)

        case HTTPoison.get(cfg.config.url) do
          {:ok, result} ->
            case result.body |> Poison.decode() do
              {:ok, json_body} ->
                if json_body["data"]
                   |> Map.has_key?(cfg.config.lang) do
                  bcast(state.id, :parsing, 2, 4)

                  json_body["data"][cfg.config.lang]["feeds"]
                  |> Enum.map(fn %{"name" => name, "url" => url} ->
                    case name do
                      "station_information" ->
                        write_data(url, :stat_info, state.id)
                        bcast(state.id, :system_information, 3, 4)

                      "ebikes_at_stations" ->
                        write_data(url, :ebikes_at_stations, state.id)
                        bcast(state.id, :system_information, 4, 4)

                      _otherwise ->
                        :ok
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

              {:error, error} ->
                Logger.info(error.data)
                {:noreply, state}
            end

          {:error, error} ->
            Logger.info(error.reason)
            {:noreply, state}
        end

      false ->
        bcast(state.id, :disabled)
        {:noreply, state}
    end

    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def sys_info_as_stats(id) do
    s = Storage.get_sys_info!(:src, id)
    %{
      name: s.name,
      start_date: s.start_date,
      system_id: s.system_id,
      operator: s.operator,
      tz: s.timezone,
    }
  end

  def source_stats(id) do
    %{
      stations: Storage.count_gbfs_stations(id),
      slots: Storage.count_gbfs_slots(id),
      bikes: Storage.count_gbfs_bikes(id),
      ebikes: Storage.count_gbfs_ebikes(id),
    }
  end
end
