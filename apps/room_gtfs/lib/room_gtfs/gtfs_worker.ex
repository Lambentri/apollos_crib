defmodule RoomGtfs.Worker do
  @moduledoc false
  use Parent.GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus

  def start_link(opts) do
    Parent.GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs" <> opts[:name]))
  end

  # Public
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

  def get_current_realtime(name, trips, stop) do
    "gtfs#{name}"
    |> via_tuple
    |> GenServer.call({:query_realtime, trips, stop}, 30_000)
  end

  def query_stop(id, query) do
    inst = Configuration.get_source!(id)
    res = Storage.get_upcoming_arrivals_for_stop(id, query.stop)

    case inst.config.url_rt_tu do
      nil ->
        res

      _val ->
        trips = res |> Enum.map(fn x -> x.trip_id end)

        case get_current_realtime(id, trips, query.stop) do
          [] ->
            res

          rtvals ->
            res
            |> Enum.map(fn x ->
              case Enum.find(rtvals, fn v -> x.trip_id == v.trip_update.trip.trip_id end) do
                nil ->
                  x

                val ->
                  case val.trip_update.stop_time_update do
                    nil ->
                      x

                    _stop_time_update ->
                      case val.trip_update.stop_time_update.arrival do
                        nil ->
                          x

                        _arrival ->
                          x
                          |> Map.put(
                            :arrival_time_live_ts,
                            val.trip_update.stop_time_update.arrival.time
                          )
                          |> Map.put(
                            :arrival_time_live_delay,
                            val.trip_update.stop_time_update.arrival.delay
                          )
                          |> Map.put(
                            :arrival_time_live_uncertianty,
                            val.trip_update.stop_time_update.arrival.uncertainty
                          )
                      end
                  end
              end
            end)
        end
    end
  end

  # etc
  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(4),
      run: fn -> RoomGtfs.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 10
    )

    {:ok, child_rt} = Parent.start_child({RoomGtfs.Worker.RT, opts})
    {:ok, child_s(tatic)} = Parent.start_child({RoomGtfs.Worker.Static, opts})

    {:ok,
     %{
       id: opts[:name],
       inst: nil,
       child_rt: child_rt,
       child_static: child_static
     }}
  end

  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:update_static, state) do
    GenServer.cast(state.child_static, :update_static)
    {:noreply, state}
  end

  def handle_cast(:update_realtime, state) do
    GenServer.cast(state.child_rt, :update_realtime)
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call({:query_realtime, trips, stop}, _from, state) do
    r =
      try do
        GenServer.call(state.child_rt, {:query_realtime, trips, stop})
      catch
        :exit, _ ->
          IO.puts("timeout? exit")
          []
      after
        []
      end

    {:reply, r, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end

defmodule RoomGtfs.Worker.RT do
  use GenServer
  @registry :zeus

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs-rt" <> opts[:name]))
  end

  def update_realtime_data(name) do
    "gtfs-rt#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_realtime)
  end

  def refresh_db_cfg(name) do
    "gtfs-rt#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(4),
      run: fn -> RoomGtfs.Worker.RT.refresh_db_cfg(opts[:name]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: :timer.seconds(30),
      run: fn -> RoomGtfs.Worker.RT.update_realtime_data(opts[:name]) end,
      initial_delay: 100
    )

    {:ok,
     %{
       id: opts[:name],
       inst: nil,
       rt_sa: nil,
       rt_tu: nil,
       rt_vp: nil
     }}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def fetch_rt_url(url) do
    case HTTPoison.get(url, [], follow_redirect: true) do
      {:ok, result} -> {:ok, result.body |> TransitRealtime.FeedMessage.decode()}
      {:error, error} -> {:error, error}
    end
  end

  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:update_realtime, state) do
    state =
      case state.inst.config |> Map.get(:url_rt_sa) do
        nil ->
          state

        val ->
          case fetch_rt_url(val) do
            {:ok, data_sa} ->
              state |> Map.put(:rt_sa, data_sa)

            {:error, error} ->
              Logger.info(
                "failed to fetch gtfs-rt url[sa] for '#{state.inst.name}', reason: #{error.reason}"
              )

              state
          end
      end

    state =
      case state.inst.config |> Map.get(:url_rt_tu) do
        nil ->
          state

        val ->
          case fetch_rt_url(val) do
            {:ok, data_tu} ->
              state |> Map.put(:rt_tu, data_tu)

            {:error, error} ->
              Logger.info(
                "failed to fetch gtfs-rt url[tu] for '#{state.inst.name}', reason: #{error.reason}"
              )

              state
          end
      end

    state =
      case state.inst.config |> Map.get(:url_rt_vp) do
        nil ->
          state

        val ->
          case fetch_rt_url(val) do
            {:ok, data_vp} ->
              state |> Map.put(:rt_vp, data_vp)

            {:error, error} ->
              Logger.info(
                "failed to fetch gtfs-rt url[vp] for '#{state.inst.name}', reason: #{error.reason}"
              )

              state
          end
      end

    {:noreply, state}
  end

  def handle_call({:query_realtime, trips, stop}, _from, state) do
    #    IO.inspect(trips)

    # filter out the protobuf for all relevant trips and then the relevant stop on that trip, nice and small
    relevant_trips =
      state.rt_tu.entity
      |> Enum.filter(fn x -> Enum.member?(trips, x.trip_update.trip.trip_id) end)
      |> Enum.map(fn x ->
        x
        |> Kernel.put_in(
          [Access.key(:trip_update, %{}), Access.key(:stop_time_update, %{})],
          x.trip_update.stop_time_update
          |> Enum.filter(fn x -> x.stop_id == stop end)
          |> List.first()
        )
      end)

    {:reply, relevant_trips, state}
  end
end

defmodule RoomGtfs.Worker.Static do
  use GenServer
  require Logger
  @registry :zeus

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs-st" <> opts[:name]))
  end

  defp bcast(id, file, complete, total) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, file, complete, total})
  end

  def init(opts) do
    {:ok,
     %{
       id: opts[:name]
     }}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  defp write_file(contents, type, id) do
    datetime = NaiveDateTime.local_now()
    Logger.info("GTFS::#{id} writing #{type}")

    case type do
      :routes -> RoomSanctum.Storage.truncate_route(id)
      :stops -> RoomSanctum.Storage.truncate_stop(id)
      :stop_times -> RoomSanctum.Storage.truncate_stop_time(id)
      _ -> :ok
    end

    contents
    |> Stream.filter(fn {status, data} -> status == :ok end)
    |> Stream.uniq()
    |> Stream.map(fn {status, x} ->
      relevant_data =
        x
        |> Map.put("source_id", id)
        |> Map.put("inserted_at", datetime)
        |> Map.put("updated_at", datetime)

      case type do
        :agency ->
          RoomSanctum.Storage.change_agency(%RoomSanctum.Storage.GTFS.Agency{}, relevant_data).changes

        :calendar ->
          RoomSanctum.Storage.change_calendar(%RoomSanctum.Storage.GTFS.Calendar{}, relevant_data).changes

        :directions ->
          RoomSanctum.Storage.change_direction(
            %RoomSanctum.Storage.GTFS.Direction{},
            relevant_data
          ).changes

        :routes ->
          RoomSanctum.Storage.change_route(%RoomSanctum.Storage.GTFS.Route{}, relevant_data).changes

        :stops ->
          RoomSanctum.Storage.change_stop(%RoomSanctum.Storage.GTFS.Stop{}, relevant_data).changes

        :stop_times ->
          RoomSanctum.Storage.change_stop_time(
            %RoomSanctum.Storage.GTFS.StopTime{},
            relevant_data
          ).changes

        :trips ->
          RoomSanctum.Storage.change_trip(%RoomSanctum.Storage.GTFS.Trip{}, relevant_data).changes
      end
      |> Map.put(:inserted_at, datetime)
      |> Map.put(:updated_at, datetime)
    end)
    |> Stream.chunk_every(2000)
    |> Stream.map(fn chunked_data ->
      chunked_data =
        chunked_data
        |> Enum.uniq()

      case type do
        :agency ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Agency,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :agency_id]
          )

        :calendar ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Calendar,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :service_id]
          )

        :directions ->
          Repo.insert_all(
            RoomSanctum.Storage.GTFS.Direction,
            chunked_data,
            on_conflict: {:replace_all_except, [:id]},
            conflict_target: [:source_id, :route_id, :direction_id]
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
            conflict_target: [:source_id, :trip_id]
          )
      end
    end)
    |> Enum.count()

    DateTime.utc_now()
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
            |> Enum.map(fn {name, data} ->
              as_csv =
                data
                |> String.split("\n")
                |> Enum.filter(fn x -> x != "" end)
                |> CSV.decode(headers: true)

              case name do
                'agency.txt' ->
                  write_file(as_csv, :agency, state.id)
                  bcast(state.id, :agency, 3, 9)

                'calendar.txt' ->
                  write_file(as_csv, :calendar, state.id)
                  bcast(state.id, :calendar, 4, 9)

                'directions.txt' ->
                  write_file(as_csv, :directions, state.id)
                  bcast(state.id, :directions, 5, 9)

                'routes.txt' ->
                  write_file(as_csv, :routes, state.id)
                  bcast(state.id, :routes, 6, 9)

                'stops.txt' ->
                  write_file(as_csv, :stops, state.id)
                  bcast(state.id, :stops, 7, 9)

                'stop_times.txt' ->
                  write_file(as_csv, :stop_times, state.id)
                  bcast(state.id, :stop_times, 8, 9)

                'trips.txt' ->
                  write_file(as_csv, :trips, state.id)
                  bcast(state.id, :trips, 9, 9)

                _other ->
                  :ok
              end
            end)

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
end
