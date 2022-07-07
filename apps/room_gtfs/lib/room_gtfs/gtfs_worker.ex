defmodule RoomGtfs.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs" <> opts[:name]))
  end

  def refresh_db_cfg(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def update_static_data(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static)
  end

  def update_realtime_data(name) do
    "gtfs#{name}"
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
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, file, complete, total})
  end

  defp write_file(contents, type, id) do
    datetime = NaiveDateTime.local_now
    Logger.info("GTFS::#{id} writing #{type}")
    case type do
      :routes -> RoomSanctum.Storage.truncate_route(id)
      :stops -> RoomSanctum.Storage.truncate_stop(id)
      :stop_times -> RoomSanctum.Storage.truncate_stop_time(id)
      _ -> :ok
    end

    contents
    |> Stream.filter(fn {status, data} -> status == :ok end)
    |> Stream.uniq
    |> Stream.map(
         fn {status, x} ->
           relevant_data = x
                           |> Map.put("source_id", id)
                           |> Map.put("inserted_at", datetime)
                           |> Map.put("updated_at", datetime)

           case type do
             :agency ->
               RoomSanctum.Storage.change_agency(%RoomSanctum.Storage.GTFS.Agency{}, relevant_data).changes
             :calendar ->
               RoomSanctum.Storage.change_calendar(%RoomSanctum.Storage.GTFS.Calendar{}, relevant_data).changes
             :directions ->
               RoomSanctum.Storage.change_direction(%RoomSanctum.Storage.GTFS.Direction{}, relevant_data).changes
             :routes ->
               RoomSanctum.Storage.change_route(%RoomSanctum.Storage.GTFS.Route{}, relevant_data).changes
             :stops ->
               RoomSanctum.Storage.change_stop(%RoomSanctum.Storage.GTFS.Stop{}, relevant_data).changes
             :stop_times ->
               RoomSanctum.Storage.change_stop_time(%RoomSanctum.Storage.GTFS.StopTime{}, relevant_data).changes
             :trips ->
               RoomSanctum.Storage.change_trip(%RoomSanctum.Storage.GTFS.Trip{}, relevant_data).changes
           end
           |> Map.put(:inserted_at, datetime)
           |> Map.put(:updated_at, datetime)
         end
       )
    |> Stream.chunk_every(2000)
    |> Stream.map(
         fn chunked_data ->
           chunked_data = chunked_data
                          |> Enum.uniq
           case type do
             :agency ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.Agency,
                 chunked_data,
                 on_conflict: {:replace_all_except, [:id]},
                 conflict_target: [:source_id, :agency_id],
               )
             :calendar ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.Calendar,
                 chunked_data,
                 on_conflict: {:replace_all_except, [:id]},
                 conflict_target: [:source_id, :service_id],
               )
             :directions ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.Direction,
                 chunked_data,
                 on_conflict: {:replace_all_except, [:id]},
                 conflict_target: [:source_id, :route_id, :direction_id],
               )
             :routes ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.Route,
                 chunked_data
               )
             :stops ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.Stop,
                 chunked_data
               )
             :stop_times ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.StopTime,
                 chunked_data
               )
             :trips ->
               Repo.insert_all(
                 RoomSanctum.Storage.GTFS.Trip,
                 chunked_data,
                 on_conflict: {:replace_all_except, [:id]},
                 conflict_target: [:source_id, :trip_id],
               )
           end
         end
       )
    |> Enum.count
    DateTime.utc_now
  end


  def handle_cast(:update_static, state) do
    Logger.info("GTFS::#{state.id} updating static info")
    cfg = Configuration.get_source!(state.id)
    bcast(state.id, :downloading, 1, 9)
    case HTTPoison.get(cfg.config.url) do
      {:ok, result} ->
        bcast(state.id, :extracting, 2, 9)
        case result.body
             |> :zip.unzip([:memory]) do
          {:ok, files} ->
            files
            |> Enum.map(
                 fn {name, data} ->
                   as_csv = data
                            |> String.split("\n")
                            |> Enum.filter(fn x -> x != "" end)
                            |> CSV.decode([headers: true])
                   case name do
                     'agency.txt' -> write_file(as_csv, :agency, state.id)
                                     bcast(state.id, :agency, 3, 9)
                     'calendar.txt' -> write_file(as_csv, :calendar, state.id)
                                       bcast(state.id, :calendar, 4, 9)
                     'directions.txt' -> write_file(as_csv, :directions, state.id)
                                         bcast(state.id, :directions, 5, 9)
                     'routes.txt' -> write_file(as_csv, :routes, state.id)
                                     bcast(state.id, :routes, 6, 9)
                     'stops.txt' -> write_file(as_csv, :stops, state.id)
                                    bcast(state.id, :stops, 7, 9)
                     'stop_times.txt' -> write_file(as_csv, :stop_times, state.id)
                                         bcast(state.id, :stop_times, 8, 9)
                     'trips.txt' -> write_file(as_csv, :trips, state.id)
                                    bcast(state.id, :trips, 9, 9)
                     _other -> :ok
                   end
                 end
               )
            Logger.info("GTFS::#{state.id} completed import")
          {:error, _info} ->
            bcast(state.id, :error, 1, 1)
            Logger.info("GTFS::#{state.id} Got invalid zip file #{_info.reason}")
        end
      {:error, info} ->
        Logger.info(info.reason)
    end
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
