defmodule RoomGtfs.Worker do
  @moduledoc false
  use Parent.GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo

  @registry :zeus
  # 4 weeks
  @default_refresh_seconds 604_800 * 4

  def start_link(opts) do
    Parent.GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs" <> opts[:name]))
  end

  # Public
  def refresh_db_cfg(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def scheduled_static(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:scheduled_static)
  end

  def update_static_data(name) do
    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static)
  end

  def update_static_data(name, :str) do
    IO.puts("qqq")

    "gtfs#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static_str)
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
    res = Storage.get_upcoming_arrivals_for_stop(id, query.stop) |> Storage.fix_arrival_times

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

    Periodic.start_link(
      every: :timer.seconds(60),
      when: fn -> match?(%Time{hour: 0, minute: 0}, Time.utc_now()) end,
      run: fn -> RoomGtfs.Worker.scheduled_static(opts[:name]) end
    )

    {:ok, child_rt} = Parent.start_child({RoomGtfs.Worker.RT, opts})
    {:ok, child_static} = Parent.start_child({RoomGtfs.Worker.Static, opts})

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

  def handle_cast(:scheduled_static, state) do
    inst = state.inst

    if inst.enabled do
      diff_period = inst.meta.run_period || @default_refresh_seconds
      last_run = inst.meta.last_run

      case last_run do
        nil ->
          RoomGtfs.Worker.update_static_data(state.id)

        val ->
          case DateTime.diff(DateTime.utc_now(), val) do
            diff when diff > diff_period ->
              RoomGtfs.Worker.update_static_data(state.id)

            _otherwise ->
              :ok
          end
      end
    end

    {:noreply, state}
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

  def source_stats(id) do
    %{
      calendars: Storage.count_calendars(id),
      directions: Storage.count_directions(id),
      routes: Storage.count_routes(id),
      stops: Storage.count_stops(id),
      stop_times: Storage.count_stop_times(id),
      trips: Storage.count_calendars(id)
    }
  end
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
      initial_delay: :timer.seconds(10)
    )

    Periodic.start_link(
      every: :timer.seconds(30),
      run: fn -> RoomGtfs.Worker.RT.update_realtime_data(opts[:name]) end,
      initial_delay: :timer.seconds(60)
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

  defp bcast(id, :disabled) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, :disabled})
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
      case state.inst.enabled do
        true ->
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

        false ->
          bcast(state.id, :disabled)
          state
      end

    {:noreply, state}
  end

  def handle_call({:query_realtime, trips, stop}, _from, state) do
    #    IO.inspect(trips)

    # filter out the protobuf for all relevant trips and then the relevant stop on that trip, nice and small
    case state.rt_tu do
      nil ->
        {:reply, [], state}

      _otherwise ->
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
end

defmodule RoomGtfs.Worker.Static do
  use GenServer
  require Logger
  @registry :zeus

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo
  alias RoomSanctum.Storage.GTFS

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gtfs-st" <> opts[:name]))
  end

  defp bcast(id, file, complete, total) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, file, complete, total})
  end

  defp bcast(id, :disabled) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, :disabled})
  end

  defp bcast(id, :done) do
    Phoenix.PubSub.broadcast(RoomSanctum.PubSub, "gtfs", {:gtfs, id, :done})
  end

  def init(opts) do

    pgopts = RoomSanctum.Repo.config()
    {:ok, pid} = Postgrex.start_link(pgopts)

    {:ok,
     %{
       id: opts[:name],
       pg_pid: pid
     }}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  defp get_cols(schema) do
    schema.__schema__(:fields)
    |> Enum.map(&Atom.to_string/1)
    |> List.delete("id")
    #    |> List.delete("updated_at")
    #    |> List.delete("inserted_at")
    |> Enum.join(", ")
  end

  defp get_cols(schema, cols) do
    schema.__schema__(:fields)
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(fn f -> Enum.member?(cols, f) end)
    |> List.delete("id")
    |> Enum.join(", ")
  end

  defp as_pg(type) do
    case type do
      :id -> "bigint"
      :string -> "varchar"
      :naive_datetime -> "timestamp"
      :time -> "time"
      :integer -> "integer"
      :float -> "double precision"
      :date -> "date"
      EctoInterval -> "interval"
    end
  end

  def get_cols_pgtypes(schema) do
    schema.__schema__(:fields)
    |> List.delete(:id)
    |> Enum.map(fn f -> {f, schema.__schema__(:type, f) |> as_pg} end)
    |> Enum.map(fn {k,v} -> "#{k}::#{v}" end)
    |> Enum.join(", ")
  end

  def get_cols_pgtypes(schema, cols) do
    schema.__schema__(:fields)
    |> List.delete(:id)
    |> Enum.filter(fn f -> Enum.member?(cols |> Enum.map(&String.to_atom/1), f) end)
    |> Enum.map(fn f -> {f, schema.__schema__(:type, f) |> as_pg} end)
    |> Enum.map(fn {k,v} -> "#{k}::#{v}" end)
    |> Enum.join(", ")
  end

  def csv_cols_to_tmp_cols(cols) do
    cols
    |> Enum.map(fn x -> "#{x} varchar" end)
    |> Enum.join(", ")
  end

  def csv_cols_to_tmp_cols(cols, :add) do
    cols
    |> Kernel.++(["inserted_at", "updated_at", "source_id"])
    |> Enum.map(fn x -> "#{x} varchar" end)
    |> Enum.join(", ")
end

  defp write_file(contents, type, id, pid) do
    datetime = NaiveDateTime.local_now()
    Logger.info("GTFS::#{id} writing #{type} (c)")

    cols_j =
      contents
      |> Stream.chunk_every(500)
      |> Stream.map(&String.split(&1 |> List.flatten() |> List.first(), "\n"))
      |> Stream.take(1)
      |> Enum.to_list()
      |> List.flatten()
      |> List.first()
      |> String.strip
      |> String.split(",")

#    cols_j = ["source_id" |cols_j]
      cols_j_plus = cols_j ++ ["inserted_at", "updated_at", "source_id"]

#    contents |> Stream.take(500) |> Enum.to_list() |> IO.inspect


    # add truncation here as necessary
    case type do
      :agencies -> RoomSanctum.Storage.truncate_agency(id)
      :calendars -> RoomSanctum.Storage.truncate_calendar(id)
      :directions -> RoomSanctum.Storage.truncate_direction(id)
      :routes -> RoomSanctum.Storage.truncate_route(id)
      :stops -> RoomSanctum.Storage.truncate_stop(id)
      :stop_times -> RoomSanctum.Storage.truncate_stop_time(id)
      :trips -> RoomSanctum.Storage.truncate_trip(id)
      _ -> :ok
    end

    # set our variables based on the type
    {table, columns, pg_cols} =
      case type do
        :agencies -> {:gtfs_agencies, [GTFS.Agency |> get_cols(cols_j_plus)], GTFS.Agency |> get_cols_pgtypes(cols_j_plus)}
        :calendars -> {:gtfs_calendars, [GTFS.Calendar |> get_cols(cols_j_plus)], GTFS.Calendar |> get_cols_pgtypes(cols_j_plus)}
        :directions -> {:gtfs_directions, [GTFS.Direction |> get_cols(cols_j_plus)], GTFS.Direction |> get_cols_pgtypes(cols_j_plus)}
        :routes -> {:gtfs_routes, [GTFS.Route |> get_cols(cols_j_plus)], GTFS.Route |> get_cols_pgtypes(cols_j_plus)}
        :stops -> {:gtfs_stops, [GTFS.Stop |> get_cols(cols_j_plus)], GTFS.Stop |> get_cols_pgtypes(cols_j_plus)}
        :stop_times -> {:gtfs_stop_times, [GTFS.StopTime |> get_cols(cols_j_plus)], GTFS.StopTime |> get_cols_pgtypes(cols_j_plus)}
        :trips -> {:gtfs_trips, [GTFS.Trip |> get_cols(cols_j_plus)], GTFS.Trip |> get_cols_pgtypes(cols_j_plus)}
      end

#    IO.inspect({table, columns, pg_cols})
    opts = RoomSanctum.Repo.config()
#    {:ok, pid} = Postgrex.start_link(opts)

    tmp_table_name = "tmp_#{type}_#{id}"

    Postgrex.transaction(
      pid,
      fn conn ->
        # temp table
        qt =
          Postgrex.prepare!(
            conn,
            "",
            "CREATE TEMPORARY TABLE #{tmp_table_name} (#{cols_j |> csv_cols_to_tmp_cols})"
          )

        Postgrex.execute(conn, qt, [])

        qt2 =
          Postgrex.prepare!(
            conn,
            "",
            "CREATE TEMPORARY TABLE #{tmp_table_name}_allcols (#{cols_j |> csv_cols_to_tmp_cols(:add)})"
          )

        Postgrex.execute(conn, qt2, [])

        # write csv
        stream =
          Postgrex.stream(
            conn,
            "COPY #{tmp_table_name}(#{cols_j |> Enum.join(",")}) FROM STDIN CSV HEADER DELIMITER ','",
            []
          )

        Enum.into(contents, stream)

        qtc =
          Postgrex.prepare!(
            conn,
            "",
            "INSERT INTO #{tmp_table_name}_allcols (#{cols_j |> Enum.join(",")}) SELECT * FROM #{tmp_table_name}"
          )

        Postgrex.execute(conn, qtc, [])

        # update fields
        qtu =
          Postgrex.prepare!(
            conn,
            "",
            "UPDATE #{tmp_table_name}_allcols SET inserted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP, source_id = #{id}"
          )

        Postgrex.execute(conn, qtu, [])

        # write into dest table
        qs =
          Postgrex.prepare!(
            conn,
            "",
            "INSERT INTO #{atom_to_table(type)} (#{columns}) SELECT #{pg_cols} FROM #{tmp_table_name}_allcols"
          )

        Postgrex.execute(conn, qs, [])

#        qd = Postgrex.prepare!(conn, "", "DROP TABLE #{tmp_table_name}")
#        Postgrex.execute(conn, qd, [])
      end,
      timeout: :infinity
    ) |> IO.inspect
  end

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

  defp file_to_atom(filename) do
    case filename do
      "agency.txt" ->
        :agencies

      "calendar.txt" ->
        :calendars

      "directions.txt" ->
        :directions

      "routes.txt" ->
        :routes

      "stops.txt" ->
        :stops

      "stop_times.txt" ->
        :stop_times

      "trips.txt" ->
        :trips
    end
  end

  def file_to_order(filename) do
    case filename do
      "agency.txt" -> 3
      "calendar.txt" -> 4
      "directions.txt" -> 5
      "routes.txt" -> 6
      "stops.txt" -> 7
      "stop_times.txt" -> 8
      "trips.txt" -> 9
    end
  end

  defp atom_to_table(atom) do
    "gtfs_#{atom}"
  end

  @impl true
  def handle_cast(:update_static, state) do
    cfg = Configuration.get_source!(state.id)
    IO.puts("kkk")

    case cfg.enabled do
      true ->
        Logger.info("GTFS::#{state.id} updating static info")
        bcast(state.id, :downloading, 1, 9)

        case HTTPoison.get(cfg.config.url) do
          {:ok, result} ->
            bcast(state.id, :extracting, 2, 9)

            case result.body |> Unzip.InMem.new() |> Unzip.new() do
              {:ok, unzip} ->
                files = Unzip.list_entries(unzip)

                files
                |> Enum.map(fn e ->
                  if Enum.member?(
                       [
                        "agency.txt",
                        "calendar.txt",
                        "directions.txt",
                        "routes.txt",
                        "stops.txt",
                        "stop_times.txt",
                        "trips.txt",
                       ],
                       e.file_name
                     ) do

                    bcast(state.id, file_to_atom(e.file_name), file_to_order(e.file_name), 9)

                    Unzip.file_stream!(unzip, e.file_name)
                    |> write_file(file_to_atom(e.file_name), state.id, state.pg_pid)

                    #                    bcast(state.id, :stop_times, 8, 9)
                  end
                end)
              Configuration.update_source(cfg, %{meta: %{last_run: DateTime.utc_now()}})
              bcast(state.id, :done)
              {:error, term} ->
                Logger.error(term)
            end
        end
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:update_static_old, state) do
    cfg = Configuration.get_source!(state.id)

    case cfg.enabled do
      true ->
        Logger.info("GTFS::#{state.id} updating static info")
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
                      write_file(data, :stop_times, state.id, via: :copy)
                      bcast(state.id, :stop_times, 8, 9)

                    'trips.txt' ->
                      write_file(as_csv, :trips, state.id)
                      bcast(state.id, :trips, 9, 9)

                    _other ->
                      :ok
                  end
                end)

                Logger.info("GTFS::#{state.id} completed import")

                Configuration.update_source_meta(cfg, %{last_run: DateTime.utc_now()})

              {:error, _info} ->
                bcast(state.id, :error, 1, 1)
                Logger.info("GTFS::#{state.id} Got invalid zip file #{_info.reason}")
            end

          {:error, info} ->
            Logger.info(info.reason)
        end

      false ->
        bcast(state.id, :disabled)
        {:noreply, state}
    end

    {:noreply, state}
  end
end
