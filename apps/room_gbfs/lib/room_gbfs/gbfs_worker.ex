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
  @static_refresh_seconds 86_400

  # Ten hours, and it always was: this went to `:timer.minutes/1` while being
  # called seconds. Left where it is now that the counts refresh on the five
  # minute pass -- what the static pass still carries is station locations and
  # vehicle types, which do not change between one day and the next -- but
  # named for what it does.
  @static_delay_minutes 600

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
      initial_delay: :timer.minutes(@static_delay_minutes)
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

  # A station query answers with the dock; an area query answers with whatever
  # is loose within its radius. Same source, same query struct, different
  # question -- see RoomSanctum.Configuration.Queries.GBFS.
  def query_stop(id, %{mode: :area} = query) do
    bikes = Storage.free_bikes_near_foci(id, query.foci_id, query.radius)

    # Docks second, so a mixed answer still leads with what is loose nearby --
    # which is the thing an area query was asked about.
    case Map.get(query, :include_docks) do
      true -> bikes ++ Storage.stations_near_foci(id, query.foci_id, query.radius)
      _ -> bikes
    end
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

  # `lang` is only used to pick one string out of v3's localised name lists;
  # a v2 feed never reaches that code.
  defp write_data(url, type, id, lang) do
    dt = NaiveDateTime.local_now()
    Logger.info("GBFS::#{id} retrieving #{url}")

    # Operators move hosts and publish 301s from the old address -- Baywheels
    # now redirects to gbfs.lyftbikes.com -- so redirects have to be followed or
    # the body is an empty redirect page.
    case HTTPoison.get(url, [], follow_redirect: true) do
      {:ok, result} ->
        case decode_feed(result.body, id, url) do
          {:ok, json} -> write_feed(type, json, id, dt, lang)
          :error -> :error
        end

      {:error, info} ->
        Logger.info(info.reason)
    end
  end

  # A %Jason.DecodeError{} has no :reason -- reading one raised a KeyError of
  # its own, so a feed that came back as an HTML error page took the worker
  # down instead of being skipped until the next pass.
  @doc false
  def decode_feed(body, id, url) do
    case Jason.decode(body, keys: :atoms) do
      {:ok, json} ->
        {:ok, json}

      {:error, error} ->
        Logger.error("GBFS::#{id} #{url} returned non-JSON: #{Exception.message(error)}")
        :error
    end
  end

  defp write_feed(:sys_info, json, id, _dt, lang) do
    Repo.insert(
      RoomSanctum.Storage.change_sys_info(
        %RoomSanctum.Storage.GBFS.V1.SysInfo{},
        json.data
        |> RoomGbfs.V3.system_information(lang)
        |> Map.put(:source_id, id |> intify)
      ),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :system_id]
    )
  end

  defp write_feed(:stat_info, json, id, dt, lang) do
    data =
      json.data.stations
      |> Enum.map(&RoomGbfs.V3.station_info(&1, lang))
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
  end

  defp write_feed(:stat_status, json, id, dt, _lang) do
    # v3 dropped the electric count; the types stored from
    # vehicle_types.json are what puts it back.
    electric =
      id
      |> intify()
      |> RoomSanctum.Storage.gbfs_vehicle_types()
      |> RoomGbfs.V3.electric_type_ids()

    data =
      json.data.stations
      |> Enum.map(&RoomGbfs.V3.station_status(&1, electric))
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
  end

  defp write_feed(:free_bike, json, id, dt, _lang) do
    # v3 calls them vehicles and puts them under `vehicles`.
    data =
      (Map.get(json.data, :bikes) || Map.get(json.data, :vehicles) || [])
      |> Enum.map(&RoomGbfs.V3.vehicle_status/1)
      |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
      |> Enum.map(fn x ->
        point = %Geo.Point{coordinates: {x.lon, x.lat}, srid: 4326}
        x |> Map.put(:point, point)
      end)
      |> Enum.map(fn x ->
        RoomSanctum.Storage.change_free_bike_status(
          %RoomSanctum.Storage.GBFS.V1.FreeBikeStatus{},
          x
        ).changes
        |> inj_iddt(id, dt)
      end)

    RoomSanctum.Storage.truncate_free_bike_status(id)

    Repo.insert_all(
      RoomSanctum.Storage.GBFS.V1.FreeBikeStatus,
      data,
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :bike_id]
    )
  end

  defp write_feed(:vehicle_types, json, id, dt, lang) do
    data =
      json.data.vehicle_types
      |> Enum.map(&RoomGbfs.V3.vehicle_types(&1, lang))
      |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
      |> Enum.map(fn x ->
        RoomSanctum.Storage.change_vehicle_types(
          %RoomSanctum.Storage.GBFS.V1.VehicleTypes{},
          x
        ).changes
        |> inj_iddt(id, dt)
      end)

    RoomSanctum.Storage.truncate_vehicle_types(id)

    Repo.insert_all(
      RoomSanctum.Storage.GBFS.V1.VehicleTypes,
      data,
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :vehicle_type_id]
    )
  end

  defp write_feed(:pricing_plans, json, id, dt, _lang) do
    data =
      json.data.plans
      |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
      |> Enum.map(fn x ->
        RoomSanctum.Storage.change_system_pricing_plans(
          %RoomSanctum.Storage.GBFS.V1.SystemPricingPlans{},
          x
        ).changes
        |> inj_iddt(id, dt)
      end)

    RoomSanctum.Storage.truncate_system_pricing_plans(id)

    Repo.insert_all(
      RoomSanctum.Storage.GBFS.V1.SystemPricingPlans,
      data,
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :plan_id]
    )
  end

  defp write_feed(:geofencing_zones, json, id, dt, _lang) do
    data =
      json.data.geofencing_zones.features
      |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
      |> Enum.map(fn x ->
        point = %Geo.MultiPolygon{coordinates: x.geometry.coordinates, srid: 4326}
        x |> Map.put(:place, point)
      end)
      |> Enum.map(fn x ->
        RoomSanctum.Storage.change_geo_fencing_zones(
          %RoomSanctum.Storage.GBFS.V1.GeoFencingZones{},
          x
        ).changes
        |> inj_iddt(id, dt)
      end)

    RoomSanctum.Storage.truncate_geo_fencing_zones(id)

    #                Repo.insert_all(
    #                  RoomSanctum.Storage.GBFS.V1.GeoFencingZones,
    #                  data
    #                )
  end

  defp write_feed(:sys_hours, _json, _id, _dt, _lang) do
    :ok
  end

  defp write_feed(:sys_cal, _json, _id, _dt, _lang) do
    :ok
  end

  defp write_feed(:sys_regions, _json, _id, _dt, _lang) do
    :ok
  end

  defp write_feed(:sys_alerts, json, id, dt, _lang) do
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

  defp write_feed(:ebikes_at_stations, json, id, dt, _lang) do
    data =
      json.data.stations
      |> Enum.map(fn x -> inj_iddt(x, id, dt) end)
      |> Enum.map(fn x ->
        cs =
          RoomSanctum.Storage.change_ebikes_at_stations(
            %RoomSanctum.Storage.GBFS.V1.EbikesAtStations{},
            x
          ).changes
          |> inj_iddt(id, dt)

        eb = cs.ebikes |> Enum.map(fn eb -> eb |> Ecto.Changeset.apply_changes() end)
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

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:refresh_db_cfg, state) do
    {:noreply, state |> Map.put(:inst, nil)}
  end

  @tfh 14

  # Each discovery feed this worker writes, in v2's names: what write_data/4
  # calls it, the event broadcast once it is written, and its step of @tfh.
  @static_feeds %{
    "ebikes_at_stations" => {:ebikes_at_stations, :system_information, 3},
    "system_information" => {:sys_info, :system_information, 4},
    "station_information" => {:stat_info, :system_information, 5},
    "station_status" => {:stat_status, :system_information, 6},
    "free_bike_status" => {:free_bike, :system_information, 7},
    "system_hours" => {:sys_hours, :system_information, 8},
    "system_calendar" => {:sys_cal, :system_information, 9},
    "system_regions" => {:sys_regions, :system_information, 10},
    "system_alerts" => {:sys_alerts, :system_alerts, 11},
    "vehicle_types" => {:vehicle_types, :vehicle_types, 12},
    "system_pricing_plans" => {:pricing_plans, :pricing_plans, 13},
    "geofencing_zones" => {:geofencing_zones, :geofencing_zones, 14}
  }

  @impl true
  def handle_cast(:update_static, state) do
    cfg = Configuration.get_source!(state.id)

    case cfg.enabled do
      true ->
        Logger.info("GBFS::#{state.id} updating static info ")
        bcast(state.id, :downloading, 1, @tfh)
        update_static(cfg, state.id)
        {:noreply, state}

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
        bcast(state.id, :downloading, 1, 5)
        update_realtime(cfg, state.id)
        {:noreply, state}

      false ->
        bcast(state.id, :disabled)
        {:noreply, state}
    end
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp update_static(cfg, id) do
    case HTTPoison.get(cfg.config.url, [], follow_redirect: true) do
      {:ok, result} ->
        result
        |> discovery_json(id, cfg.config.url)
        |> RoomGbfs.V3.feeds(cfg.config.lang)
        |> write_static_feeds(id, cfg.config.lang)

      {:error, info} ->
        Logger.info(info.reason)
    end
  end

  # decode! here took the whole worker down when the body was not JSON,
  # which is exactly what an unfollowed redirect hands you.
  defp discovery_json(result, id, url) do
    case Jason.decode(result.body) do
      {:ok, decoded} ->
        decoded

      {:error, _} ->
        Logger.error(
          "GBFS::#{id} discovery returned non-JSON (HTTP #{result.status_code}) from #{url}"
        )

        %{}
    end
  end

  defp write_static_feeds({:ok, version, feeds}, id, lang) do
    if version == :v3 do
      Logger.info("GBFS::#{id} discovery is v3")
    end

    bcast(id, :parsing, 2, @tfh)

    feeds
    # Vehicle types first: station_status needs them stored to
    # work out how many of its bikes are electric, and operators
    # list the feeds in whatever order suits them.
    |> Enum.sort_by(&RoomGbfs.V3.feed_order/1)
    |> Enum.each(&write_static_feed(&1, id, lang))
  end

  defp write_static_feeds({:error, languages}, id, lang), do: language_error(id, languages, lang)

  defp write_static_feed(%{"name" => name, "url" => url}, id, lang) do
    # v3 renamed the loose-vehicle feed; everything below is
    # written in v2's names, which is the one dialect this worker
    # speaks.
    case Map.fetch(@static_feeds, RoomGbfs.V3.feed_name(name)) do
      {:ok, {type, event, step}} ->
        write_data(url, type, id, lang)
        bcast(id, event, step, @tfh)

      :error ->
        Logger.info("GBFS::#{id} System has unhandled file #{RoomGbfs.V3.feed_name(name)}")
    end
  end

  # The feeds the five minute pass refreshes, and each one's step of five.
  @realtime_feeds %{
    "station_information" => {:stat_info, 3},
    # The counts. Fetched here rather than only on the
    # daily static pass, which is how a dock could report
    # yesterday's bikes for a whole day.
    "station_status" => {:stat_status, 4},
    "ebikes_at_stations" => {:ebikes_at_stations, 4},
    "free_bike_status" => {:free_bike, 5}
  }

  defp update_realtime(cfg, id) do
    case HTTPoison.get(cfg.config.url, [], follow_redirect: true) do
      {:ok, result} ->
        case result.body |> Jason.decode() do
          {:ok, json_body} ->
            json_body
            |> RoomGbfs.V3.feeds(cfg.config.lang)
            |> write_realtime_feeds(id, cfg.config.lang)

          {:error, error} ->
            Logger.info(error.data)
        end

      {:error, error} ->
        Logger.info(error.reason)
    end
  end

  defp write_realtime_feeds({:ok, _version, feeds}, id, lang) do
    bcast(id, :parsing, 2, 5)

    feeds
    |> Enum.sort_by(&RoomGbfs.V3.feed_order/1)
    |> Enum.each(&write_realtime_feed(&1, id, lang))
  end

  defp write_realtime_feeds({:error, languages}, id, lang),
    do: language_error(id, languages, lang)

  defp write_realtime_feed(%{"name" => name, "url" => url}, id, lang) do
    case Map.fetch(@realtime_feeds, RoomGbfs.V3.feed_name(name)) do
      {:ok, {type, step}} ->
        write_data(url, type, id, lang)
        bcast(id, :system_information, step, 5)

      :error ->
        :ok
    end
  end

  defp language_error(id, languages, lang) do
    bcast(
      id,
      :language_error,
      "Invalid Language Selected, available #{Enum.join(languages, ", ")}, selected: #{lang}"
    )
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def sys_info_as_stats(id) do
    s = Storage.get_sys_info!(:src, id)

    %{
      name: s.name,
      start_date: s.start_date,
      system_id: s.system_id,
      operator: s.operator,
      tz: s.timezone
    }
  end

  def source_stats(id) do
    %{
      stations: Storage.count_gbfs_stations(id),
      slots: Storage.count_gbfs_slots(id),
      bikes: Storage.count_gbfs_bikes(id),
      ebikes: Storage.count_gbfs_ebikes(id)
    }
  end

  def free_stats(id) do
    details =
      Storage.count_free_bikes_types(id)
      |> Enum.map(fn %{cnt: cnt, ff: ff} -> {ff, cnt} end)
      |> Map.new()

    %{
      free_bikes: Storage.count_free_bikes(id)
    }
    |> Map.merge(details)
  end
end
