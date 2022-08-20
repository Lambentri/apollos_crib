defmodule RoomSanctum.Storage do
  @moduledoc """
  The Storage context.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  alias RoomSanctum.Repo

  alias RoomSanctum.Storage.GTFS.Agency

  @doc """
  Returns the list of agencies.

  ## Examples

      iex> list_agencies()
      [%Agency{}, ...]

  """
  def list_agencies do
    Repo.all(Agency)
  end

  @doc """
  Gets a single agency.

  Raises `Ecto.NoResultsError` if the Agency does not exist.

  ## Examples

      iex> get_agency!(123)
      %Agency{}

      iex> get_agency!(456)
      ** (Ecto.NoResultsError)

  """
  def get_agency!(id), do: Repo.get!(Agency, id)

  @doc """
  Creates a agency.

  ## Examples

      iex> create_agency(%{field: value})
      {:ok, %Agency{}}

      iex> create_agency(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_agency(attrs \\ %{}) do
    %Agency{}
    |> Agency.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_agency(attrs) do
    %Agency{}
    |> Agency.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :agency_id]
    )
  end

  @doc """
  Updates a agency.

  ## Examples

      iex> update_agency(agency, %{field: new_value})
      {:ok, %Agency{}}

      iex> update_agency(agency, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_agency(%Agency{} = agency, attrs) do
    agency
    |> Agency.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a agency.

  ## Examples

      iex> delete_agency(agency)
      {:ok, %Agency{}}

      iex> delete_agency(agency)
      {:error, %Ecto.Changeset{}}

  """
  def delete_agency(%Agency{} = agency) do
    Repo.delete(agency)
  end

  def truncate_agency(source_id) do
    from(p in Agency, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking agency changes.

  ## Examples

      iex> change_agency(agency)
      %Ecto.Changeset{data: %Agency{}}

  """
  def change_agency(%Agency{} = agency, attrs \\ %{}) do
    Agency.changeset(agency, attrs)
  end

  alias RoomSanctum.Storage.GTFS.Calendar

  @doc """
  Returns the list of calendars.

  ## Examples

      iex> list_calendars()
      [%Calendar{}, ...]

  """
  def list_calendars do
    Repo.all(Calendar)
  end

  @doc """
  Gets a single calendar.

  Raises `Ecto.NoResultsError` if the Calendar does not exist.

  ## Examples

      iex> get_calendar!(123)
      %Calendar{}

      iex> get_calendar!(456)
      ** (Ecto.NoResultsError)

  """
  def get_calendar!(id), do: Repo.get!(Calendar, id)

  @doc """
  Creates a calendar.

  ## Examples

      iex> create_calendar(%{field: value})
      {:ok, %Calendar{}}

      iex> create_calendar(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_calendar(attrs \\ %{}) do
    %Calendar{}
    |> Calendar.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_calendar(attrs) do
    %Calendar{}
    |> Calendar.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :service_id]
    )
  end

  @doc """
  Updates a calendar.

  ## Examples

      iex> update_calendar(calendar, %{field: new_value})
      {:ok, %Calendar{}}

      iex> update_calendar(calendar, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_calendar(%Calendar{} = calendar, attrs) do
    calendar
    |> Calendar.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a calendar.

  ## Examples

      iex> delete_calendar(calendar)
      {:ok, %Calendar{}}

      iex> delete_calendar(calendar)
      {:error, %Ecto.Changeset{}}

  """
  def delete_calendar(%Calendar{} = calendar) do
    Repo.delete(calendar)
  end

  def truncate_calendar(source_id) do
    from(p in Calendar, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking calendar changes.

  ## Examples

      iex> change_calendar(calendar)
      %Ecto.Changeset{data: %Calendar{}}

  """
  def change_calendar(%Calendar{} = calendar, attrs \\ %{}) do
    Calendar.changeset(calendar, attrs)
  end

  alias RoomSanctum.Storage.GTFS.Direction

  @doc """
  Returns the list of directions.

  ## Examples

      iex> list_directions()
      [%Direction{}, ...]

  """
  def list_directions do
    Repo.all(Direction)
  end

  @doc """
  Gets a single direction.

  Raises `Ecto.NoResultsError` if the Direction does not exist.

  ## Examples

      iex> get_direction!(123)
      %Direction{}

      iex> get_direction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_direction!(id), do: Repo.get!(Direction, id)

  @doc """
  Creates a direction.

  ## Examples

      iex> create_direction(%{field: value})
      {:ok, %Direction{}}

      iex> create_direction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_direction(attrs \\ %{}) do
    %Direction{}
    |> Direction.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_direction(attrs) do
    %Direction{}
    |> Direction.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :route_id]
    )
  end

  @doc """
  Updates a direction.

  ## Examples

      iex> update_direction(direction, %{field: new_value})
      {:ok, %Direction{}}

      iex> update_direction(direction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_direction(%Direction{} = direction, attrs) do
    direction
    |> Direction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a direction.

  ## Examples

      iex> delete_direction(direction)
      {:ok, %Direction{}}

      iex> delete_direction(direction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_direction(%Direction{} = direction) do
    Repo.delete(direction)
  end

  def truncate_direction(source_id) do
    from(p in Direction, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking direction changes.

  ## Examples

      iex> change_direction(direction)
      %Ecto.Changeset{data: %Direction{}}

  """
  def change_direction(%Direction{} = direction, attrs \\ %{}) do
    Direction.changeset(direction, attrs)
  end

  alias RoomSanctum.Storage.GTFS.Route

  @doc """
  Returns the list of routes.

  ## Examples

      iex> list_routes()
      [%Route{}, ...]

  """
  def list_routes do
    Repo.all(Route)
  end

  @doc """
  Gets a single route.

  Raises `Ecto.NoResultsError` if the Route does not exist.

  ## Examples

      iex> get_route!(123)
      %Route{}

      iex> get_route!(456)
      ** (Ecto.NoResultsError)

  """
  def get_route!(id), do: Repo.get!(Route, id)

  @doc """
  Creates a route.

  ## Examples

      iex> create_route(%{field: value})
      {:ok, %Route{}}

      iex> create_route(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_route(attrs \\ %{}) do
    %Route{}
    |> Route.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_route(attrs) do
    %Route{}
    |> Route.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :route_id]
    )
  end

  @doc """
  Updates a route.

  ## Examples

      iex> update_route(route, %{field: new_value})
      {:ok, %Route{}}

      iex> update_route(route, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_route(%Route{} = route, attrs) do
    route
    |> Route.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a route.

  ## Examples

      iex> delete_route(route)
      {:ok, %Route{}}

      iex> delete_route(route)
      {:error, %Ecto.Changeset{}}

  """
  def delete_route(%Route{} = route) do
    Repo.delete(route)
  end

  def truncate_route(source_id) do
    from(p in Route, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking route changes.

  ## Examples

      iex> change_route(route)
      %Ecto.Changeset{data: %Route{}}

  """
  def change_route(%Route{} = route, attrs \\ %{}) do
    Route.changeset(route, attrs)
  end

  alias RoomSanctum.Storage.GTFS.StopTime

  @doc """
  Returns the list of stop_times.

  ## Examples

      iex> list_stop_times()
      [%StopTime{}, ...]

  """
  def list_stop_times do
    Repo.all(StopTime)
  end

  @doc """
  Gets a single stop_time.

  Raises `Ecto.NoResultsError` if the Stop time does not exist.

  ## Examples

      iex> get_stop_time!(123)
      %StopTime{}

      iex> get_stop_time!(456)
      ** (Ecto.NoResultsError)

  """
  def get_stop_time!(id), do: Repo.get!(StopTime, id)

  @doc """
  Creates a stop_time.

  ## Examples

      iex> create_stop_time(%{field: value})
      {:ok, %StopTime{}}

      iex> create_stop_time(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stop_time(attrs \\ %{}) do
    %StopTime{}
    |> StopTime.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_stop_time(attrs) do
    %StopTime{}
    |> StopTime.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :trip_id, :stop_id]
    )
  end

  @doc """
  Updates a stop_time.

  ## Examples

      iex> update_stop_time(stop_time, %{field: new_value})
      {:ok, %StopTime{}}

      iex> update_stop_time(stop_time, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_stop_time(%StopTime{} = stop_time, attrs) do
    stop_time
    |> StopTime.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stop_time.

  ## Examples

      iex> delete_stop_time(stop_time)
      {:ok, %StopTime{}}

      iex> delete_stop_time(stop_time)
      {:error, %Ecto.Changeset{}}

  """
  def delete_stop_time(%StopTime{} = stop_time) do
    Repo.delete(stop_time)
  end

  def truncate_stop_time(source_id) do
    from(p in StopTime, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end


  defp convert_gtfs_time(time) do
    [hour, min, second] = time |> String.split(":")
    hour = hour |> String.strip |> String.to_integer()

    hour = cond do
      hour >= 24 -> hour - 24
      true -> hour
    end
    hourzf = hour |> Integer.to_string |> String.pad_leading(2, "0")
    "#{hourzf}:#{min}:#{second}"
  end

  defp convert_gtfs(attrs) do
    attrs
    |> Map.put("arrival_time", attrs["arrival_time"] |> convert_gtfs_time)
    |> Map.put("departure_time", attrs["departure_time"] |> convert_gtfs_time)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stop_time changes.

  ## Examples

      iex> change_stop_time(stop_time)
      %Ecto.Changeset{data: %StopTime{}}

  """
  def change_stop_time(%StopTime{} = stop_time, attrs \\ %{}) do
    StopTime.changeset(stop_time, attrs |> convert_gtfs)
  end

  alias RoomSanctum.Storage.GTFS.Stop

  @doc """
  Returns the list of stops.

  ## Examples

      iex> list_stops()
      [%Stop{}, ...]

  """
  def list_stops do
    Repo.all(Stop)
  end

  @doc """
  Gets a single stop.

  Raises `Ecto.NoResultsError` if the Stop does not exist.

  ## Examples

      iex> get_stop!(123)
      %Stop{}

      iex> get_stop!(456)
      ** (Ecto.NoResultsError)

  """
  def get_stop!(id), do: Repo.get!(Stop, id)

  @doc """
  Creates a stop.

  ## Examples

      iex> create_stop(%{field: value})
      {:ok, %Stop{}}

      iex> create_stop(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stop(attrs \\ %{}) do
    %Stop{}
    |> Stop.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_stop(attrs) do
    %Stop{}
    |> Stop.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :stop_id]
    )
  end

  @doc """
  Updates a stop.

  ## Examples

      iex> update_stop(stop, %{field: new_value})
      {:ok, %Stop{}}

      iex> update_stop(stop, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_stop(%Stop{} = stop, attrs) do
    stop
    |> Stop.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stop.

  ## Examples

      iex> delete_stop(stop)
      {:ok, %Stop{}}

      iex> delete_stop(stop)
      {:error, %Ecto.Changeset{}}

  """
  def delete_stop(%Stop{} = stop) do
    Repo.delete(stop)
  end

  def truncate_stop(source_id) do
    from(p in Stop, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stop changes.

  ## Examples

      iex> change_stop(stop)
      %Ecto.Changeset{data: %Stop{}}

  """
  def change_stop(%Stop{} = stop, attrs \\ %{}) do
    Stop.changeset(stop, attrs)
  end

  alias RoomSanctum.Storage.GTFS.Trip

  @doc """
  Returns the list of trips.

  ## Examples

      iex> list_trips()
      [%Trip{}, ...]

  """
  def list_trips do
    Repo.all(Trip)
  end

  @doc """
  Gets a single trip.

  Raises `Ecto.NoResultsError` if the Trip does not exist.

  ## Examples

      iex> get_trip!(123)
      %Trip{}

      iex> get_trip!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trip!(id), do: Repo.get!(Trip, id)

  @doc """
  Creates a trip.

  ## Examples

      iex> create_trip(%{field: value})
      {:ok, %Trip{}}

      iex> create_trip(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trip(attrs \\ %{}) do
    %Trip{}
    |> Trip.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_trip(attrs) do
    %Trip{}
    |> Trip.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :trip_id]
    )
  end

  @doc """
  Updates a trip.

  ## Examples

      iex> update_trip(trip, %{field: new_value})
      {:ok, %Trip{}}

      iex> update_trip(trip, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trip(%Trip{} = trip, attrs) do
    trip
    |> Trip.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trip.

  ## Examples

      iex> delete_trip(trip)
      {:ok, %Trip{}}

      iex> delete_trip(trip)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trip(%Trip{} = trip) do
    Repo.delete(trip)
  end

  def truncate_trip(source_id) do
    from(p in Trip, where: p.source_id == ^source_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trip changes.

  ## Examples

      iex> change_trip(trip)
      %Ecto.Changeset{data: %Trip{}}

  """
  def change_trip(%Trip{} = trip, attrs \\ %{}) do
    Trip.changeset(trip, attrs)
  end

  alias RoomSanctum.Configuration, as: Cfg

  defp stringify(val) when is_integer(val) do
    val
    |> Integer.to_string()
  end

  defp stringify(val) do
    val
  end

  def get_upcoming_arrivals_for_stop(source_id, stop_id, limit \\ 16, timestamp \\ :now) do
    source = Cfg.get_source!(source_id)
    tz = source.config.tz

    timestamp =
      case timestamp do
        :now -> DateTime.now!(tz)
        _ -> timestamp
      end

    timestamp_time =
      timestamp
      |> DateTime.to_time()

    q =
      from st in StopTime,
        where:
          st.source_id == ^source_id and st.arrival_time >= ^timestamp_time and
            st.stop_id == ^stringify(stop_id),
        order_by: [
          asc: st.arrival_time
        ],
        limit: ^limit,
        left_join: s in Stop,
        on: s.stop_id == st.stop_id,
        left_join: t in Trip,
        on: t.trip_id == st.trip_id,
        left_join: r in Route,
        on: t.route_id == r.route_id,
        left_join: d in Direction,
        on: t.direction_id == d.direction_id and t.route_id == d.route_id,
        left_join: c in Calendar,
        on: t.service_id == c.service_id,
        select: %{
          arrival_time: st.arrival_time,
          departure_time: st.departure_time,
          stop_id: st.stop_id,
          stop_sequence: st.stop_sequence,
          stop: %{
            stop_address: s.stop_address,
            stop_code: s.stop_code,
            stop_desc: s.stop_desc,
            stop_id: s.stop_id,
            stop_lat: s.stop_lat,
            stop_lon: s.stop_lon,
            stop_name: s.stop_name,
            stop_url: s.stop_url
          },
          trip_id: st.trip_id,
          trip: %{
            bikes_allowed: t.bikes_allowed,
            direction_id: t.direction_id,
            direction: %{
              direction: d.direction,
              direction_id: d.direction_id
            },
            route_id: t.route_id,
            route: %{
              line_id: r.line_id,
              route_color: r.route_color,
              route_desc: r.route_desc,
              route_fare_class: r.route_fare_class,
              route_id: r.route_id,
              route_long_name: r.route_long_name,
              route_short_name: r.route_short_name,
              route_sort_order: r.route_sort_order,
              route_text_color: r.route_text_color,
              route_type: r.route_type,
              route_url: r.route_url
            },
            service_id: t.service_id,
            service: %{
              service_id: c.service_id,
              service_name: c.service_name,
              start_date: c.start_date,
              end_date: c.end_date,
              monday: c.monday,
              tuesday: c.tuesday,
              wednesday: c.wednesday,
              thursday: c.thursday,
              friday: c.friday,
              saturday: c.saturday,
              sunday: c.sunday
            },
            trip_headsign: t.trip_headsign,
            trip_id: t.trip_id,
            trip_short_name: t.trip_short_name
          }
        }

    Repo.all(q)
  end

  alias RoomSanctum.Storage.GBFS.V1.SysInfo

  @doc """
  Returns the list of gbfs_system_informations.

  ## Examples

      iex> list_gbfs_system_informations()
      [%SysInfo{}, ...]

  """
  def list_gbfs_system_informations do
    Repo.all(SysInfo)
  end

  @doc """
  Gets a single sys_info.

  Raises `Ecto.NoResultsError` if the Sys info does not exist.

  ## Examples

      iex> get_sys_info!(123)
      %SysInfo{}

      iex> get_sys_info!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sys_info!(id), do: Repo.get!(SysInfo, id)

  @doc """
  Creates a sys_info.

  ## Examples

      iex> create_sys_info(%{field: value})
      {:ok, %SysInfo{}}

      iex> create_sys_info(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sys_info(attrs \\ %{}) do
    %SysInfo{}
    |> SysInfo.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_sys_info(attrs) do
    %SysInfo{}
    |> SysInfo.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :system_id]
    )
  end

  @doc """
  Updates a sys_info.

  ## Examples

      iex> update_sys_info(sys_info, %{field: new_value})
      {:ok, %SysInfo{}}

      iex> update_sys_info(sys_info, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sys_info(%SysInfo{} = sys_info, attrs) do
    sys_info
    |> SysInfo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sys_info.

  ## Examples

      iex> delete_sys_info(sys_info)
      {:ok, %SysInfo{}}

      iex> delete_sys_info(sys_info)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sys_info(%SysInfo{} = sys_info) do
    Repo.delete(sys_info)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sys_info changes.

  ## Examples

      iex> change_sys_info(sys_info)
      %Ecto.Changeset{data: %SysInfo{}}

  """
  def change_sys_info(%SysInfo{} = sys_info, attrs \\ %{}) do
    SysInfo.changeset(sys_info, attrs)
  end

  alias RoomSanctum.Storage.GBFS.V1.StationInfo

  @doc """
  Returns the list of gbfs_station_information.

  ## Examples

      iex> list_gbfs_station_information()
      [%StationInfo{}, ...]

  """
  def list_gbfs_station_information do
    Repo.all(StationInfo)
  end

  @doc """
  Gets a single station_info.

  Raises `Ecto.NoResultsError` if the Station info does not exist.

  ## Examples

      iex> get_station_info!(123)
      %StationInfo{}

      iex> get_station_info!(456)
      ** (Ecto.NoResultsError)

  """
  def get_station_info!(id), do: Repo.get!(StationInfo, id)

  @doc """
  Creates a station_info.

  ## Examples

      iex> create_station_info(%{field: value})
      {:ok, %StationInfo{}}

      iex> create_station_info(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_station_info(attrs \\ %{}) do
    %StationInfo{}
    |> StationInfo.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_station_info(attrs) do
    %StationInfo{}
    |> StationInfo.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :station_id]
    )
  end

  @doc """
  Updates a station_info.

  ## Examples

      iex> update_station_info(station_info, %{field: new_value})
      {:ok, %StationInfo{}}

      iex> update_station_info(station_info, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_station_info(%StationInfo{} = station_info, attrs) do
    station_info
    |> StationInfo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a station_info.

  ## Examples

      iex> delete_station_info(station_info)
      {:ok, %StationInfo{}}

      iex> delete_station_info(station_info)
      {:error, %Ecto.Changeset{}}

  """
  def delete_station_info(%StationInfo{} = station_info) do
    Repo.delete(station_info)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking station_info changes.

  ## Examples

      iex> change_station_info(station_info)
      %Ecto.Changeset{data: %StationInfo{}}

  """
  def change_station_info(%StationInfo{} = station_info, attrs \\ %{}) do
    StationInfo.changeset(station_info, attrs)
  end

  alias RoomSanctum.Storage.GBFS.V1.StationStatus

  @doc """
  Returns the list of gbfs_station_status.

  ## Examples

      iex> list_gbfs_station_status()
      [%StationStatus{}, ...]

  """
  def list_gbfs_station_status do
    Repo.all(StationStatus)
  end

  @doc """
  Gets a single station_status.

  Raises `Ecto.NoResultsError` if the Station status does not exist.

  ## Examples

      iex> get_station_status!(123)
      %StationStatus{}

      iex> get_station_status!(456)
      ** (Ecto.NoResultsError)

  """
  def get_station_status!(id), do: Repo.get!(StationStatus, id)

  @doc """
  Creates a station_status.

  ## Examples

      iex> create_station_status(%{field: value})
      {:ok, %StationStatus{}}

      iex> create_station_status(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_station_status(attrs \\ %{}) do
    %StationStatus{}
    |> StationStatus.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_station_status(attrs) do
    %StationStatus{}
    |> StationStatus.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :station_id]
    )
  end

  @doc """
  Updates a station_status.

  ## Examples

      iex> update_station_status(station_status, %{field: new_value})
      {:ok, %StationStatus{}}

      iex> update_station_status(station_status, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_station_status(%StationStatus{} = station_status, attrs) do
    station_status
    |> StationStatus.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a station_status.

  ## Examples

      iex> delete_station_status(station_status)
      {:ok, %StationStatus{}}

      iex> delete_station_status(station_status)
      {:error, %Ecto.Changeset{}}

  """
  def delete_station_status(%StationStatus{} = station_status) do
    Repo.delete(station_status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking station_status changes.

  ## Examples

      iex> change_station_status(station_status)
      %Ecto.Changeset{data: %StationStatus{}}

  """
  def change_station_status(%StationStatus{} = station_status, attrs \\ %{}) do
    StationStatus.changeset(station_status, attrs)
  end

  alias RoomSanctum.Storage.GBFS.V1.Alert, as: GBFSAlert

  @doc """
  Returns the list of gbfs_alerts.

  ## Examples

      iex> list_gbfs_alerts()
      [%Alert{}, ...]

  """
  def list_gbfs_alerts do
    Repo.all(GBFSAlert)
  end

  @doc """
  Gets a single alert.

  Raises `Ecto.NoResultsError` if the Alert does not exist.

  ## Examples

      iex> get_alert!(123)
      %Alert{}

      iex> get_alert!(456)
      ** (Ecto.NoResultsError)

  """
  def get_gbfs_alert!(id), do: Repo.get!(GBFSAlert, id)

  @doc """
  Creates a alert.

  ## Examples

      iex> create_alert(%{field: value})
      {:ok, %Alert{}}

      iex> create_alert(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_gbfs_alert(attrs \\ %{}) do
    %GBFSAlert{}
    |> GBFSAlert.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_gbfs_alert(attrs) do
    %GBFSAlert{}
    |> GBFSAlert.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :alert_id]
    )
  end

  @doc """
  Updates a alert.

  ## Examples

      iex> update_alert(alert, %{field: new_value})
      {:ok, %Alert{}}

      iex> update_alert(alert, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_gnfs_alert(%GBFSAlert{} = alert, attrs) do
    alert
    |> Alert.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a alert.

  ## Examples

      iex> delete_alert(alert)
      {:ok, %Alert{}}

      iex> delete_alert(alert)
      {:error, %Ecto.Changeset{}}

  """
  def delete_gbfs_alert(%GBFSAlert{} = alert) do
    Repo.delete(alert)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking alert changes.

  ## Examples

      iex> change_alert(alert)
      %Ecto.Changeset{data: %Alert{}}

  """
  def change_gbfs_alert(%GBFSAlert{} = alert, attrs \\ %{}) do
    GBFSAlert.changeset(alert, attrs)
  end

  def get_current_information_for_bikestop(source_id, stop_id) do
    q =
      from st in StationStatus,
        where: st.source_id == ^source_id and st.station_id == ^stringify(stop_id),
        left_join: si in StationInfo,
        on: si.station_id == st.station_id,
        #        left_join: t in GBFSAlert,
        #        on: t.station_id == st.trip_id,
        select: %{
          is_installed: st.is_installed,
          is_renting: st.is_renting,
          is_returning: st.is_returning,
          last_reported: st.last_reported,
          num_bikes_available: st.num_bikes_available,
          num_bikes_disabled: st.num_bikes_disabled,
          num_docks_available: st.num_docks_available,
          num_docks_disabled: st.num_docks_disabled,
          num_ebikes_available: st.num_ebikes_available,
          station_id: st.station_id,
          station_status: st.station_status,
          capacity: si.capacity,
          lat: si.lat,
          lon: si.lon,
          place: si.place,
          name: si.name,
          short_name: si.short_name
        }

    Repo.one(q)
  end

  alias RoomSanctum.Storage.AirNow.ReportingArea

  @doc """
  Returns the list of airnow_reporting_area.

  ## Examples

      iex> list_airnow_reporting_area()
      [%ReportingArea{}, ...]

  """
  def list_airnow_reporting_area do
    Repo.all(ReportingArea)
  end

  @doc """
  Gets a single reporting_area.

  Raises `Ecto.NoResultsError` if the Reporting area does not exist.

  ## Examples

      iex> get_reporting_area!(123)
      %ReportingArea{}

      iex> get_reporting_area!(456)
      ** (Ecto.NoResultsError)

  """
  def get_reporting_area!(id), do: Repo.get!(ReportingArea, id)

  @doc """
  Creates a reporting_area.

  ## Examples

      iex> create_reporting_area(%{field: value})
      {:ok, %ReportingArea{}}

      iex> create_reporting_area(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_reporting_area(attrs \\ %{}) do
    %ReportingArea{}
    |> ReportingArea.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a reporting_area.

  ## Examples

      iex> update_reporting_area(reporting_area, %{field: new_value})
      {:ok, %ReportingArea{}}

      iex> update_reporting_area(reporting_area, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_reporting_area(%ReportingArea{} = reporting_area, attrs) do
    reporting_area
    |> ReportingArea.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a reporting_area.

  ## Examples

      iex> delete_reporting_area(reporting_area)
      {:ok, %ReportingArea{}}

      iex> delete_reporting_area(reporting_area)
      {:error, %Ecto.Changeset{}}

  """
  def delete_reporting_area(%ReportingArea{} = reporting_area) do
    Repo.delete(reporting_area)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reporting_area changes.

  ## Examples

      iex> change_reporting_area(reporting_area)
      %Ecto.Changeset{data: %ReportingArea{}}

  """
  def change_reporting_area(%ReportingArea{} = reporting_area, attrs \\ %{}) do
    ReportingArea.changeset(reporting_area, attrs)
  end

  alias RoomSanctum.Storage.AirNow.HourlyData

  @doc """
  Returns the list of airnow_hourly_data.

  ## Examples

      iex> list_airnow_hourly_data()
      [%HourlyData{}, ...]

  """
  def list_airnow_hourly_data do
    Repo.all(HourlyData)
  end

  @doc """
  Gets a single hourly_data.

  Raises `Ecto.NoResultsError` if the Hourly data does not exist.

  ## Examples

      iex> get_hourly_data!(123)
      %HourlyData{}

      iex> get_hourly_data!(456)
      ** (Ecto.NoResultsError)

  """
  def get_hourly_data!(id), do: Repo.get!(HourlyData, id)

  @doc """
  Creates a hourly_data.

  ## Examples

      iex> create_hourly_data(%{field: value})
      {:ok, %HourlyData{}}

      iex> create_hourly_data(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_hourly_data(attrs \\ %{}) do
    %HourlyData{}
    |> HourlyData.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a hourly_data.

  ## Examples

      iex> update_hourly_data(hourly_data, %{field: new_value})
      {:ok, %HourlyData{}}

      iex> update_hourly_data(hourly_data, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_hourly_data(%HourlyData{} = hourly_data, attrs) do
    hourly_data
    |> HourlyData.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a hourly_data.

  ## Examples

      iex> delete_hourly_data(hourly_data)
      {:ok, %HourlyData{}}

      iex> delete_hourly_data(hourly_data)
      {:error, %Ecto.Changeset{}}

  """
  def delete_hourly_data(%HourlyData{} = hourly_data) do
    Repo.delete(hourly_data)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking hourly_data changes.

  ## Examples

      iex> change_hourly_data(hourly_data)
      %Ecto.Changeset{data: %HourlyData{}}

  """
  def change_hourly_data(%HourlyData{} = hourly_data, attrs \\ %{}) do
    HourlyData.changeset(hourly_data, attrs)
  end

  alias RoomSanctum.Storage.AirNow.MonitoringSite

  @doc """
  Returns the list of airnow_monitoring_sites.

  ## Examples

      iex> list_airnow_monitoring_sites()
      [%MonitoringSite{}, ...]

  """
  def list_airnow_monitoring_sites do
    Repo.all(MonitoringSite)
  end

  @doc """
  Gets a single monitoring_site.

  Raises `Ecto.NoResultsError` if the Monitoring site does not exist.

  ## Examples

      iex> get_monitoring_site!(123)
      %MonitoringSite{}

      iex> get_monitoring_site!(456)
      ** (Ecto.NoResultsError)

  """
  def get_monitoring_site!(id), do: Repo.get!(MonitoringSite, id)

  @doc """
  Creates a monitoring_site.

  ## Examples

      iex> create_monitoring_site(%{field: value})
      {:ok, %MonitoringSite{}}

      iex> create_monitoring_site(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_monitoring_site(attrs \\ %{}) do
    %MonitoringSite{}
    |> MonitoringSite.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a monitoring_site.

  ## Examples

      iex> update_monitoring_site(monitoring_site, %{field: new_value})
      {:ok, %MonitoringSite{}}

      iex> update_monitoring_site(monitoring_site, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_monitoring_site(%MonitoringSite{} = monitoring_site, attrs) do
    monitoring_site
    |> MonitoringSite.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a monitoring_site.

  ## Examples

      iex> delete_monitoring_site(monitoring_site)
      {:ok, %MonitoringSite{}}

      iex> delete_monitoring_site(monitoring_site)
      {:error, %Ecto.Changeset{}}

  """
  def delete_monitoring_site(%MonitoringSite{} = monitoring_site) do
    Repo.delete(monitoring_site)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking monitoring_site changes.

  ## Examples

      iex> change_monitoring_site(monitoring_site)
      %Ecto.Changeset{data: %MonitoringSite{}}

  """
  def change_monitoring_site(%MonitoringSite{} = monitoring_site, attrs \\ %{}) do
    MonitoringSite.changeset(monitoring_site, attrs)
  end

  alias RoomSanctum.Storage.AirNow.HourlyObsData

  @doc """
  Returns the list of hourly_observations.

  ## Examples

      iex> list_hourly_observations()
      [%HourlyObsData{}, ...]

  """
  def list_hourly_observations do
    Repo.all(HourlyObsData)
  end

  @doc """
  Gets a single hourly_obs_data.

  Raises `Ecto.NoResultsError` if the Hourly obs data does not exist.

  ## Examples

      iex> get_hourly_obs_data!(123)
      %HourlyObsData{}

      iex> get_hourly_obs_data!(456)
      ** (Ecto.NoResultsError)

  """
  def get_hourly_obs_data!(id), do: Repo.get!(HourlyObsData, id)

  @doc """
  Creates a hourly_obs_data.

  ## Examples

      iex> create_hourly_obs_data(%{field: value})
      {:ok, %HourlyObsData{}}

      iex> create_hourly_obs_data(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_hourly_obs_data(attrs \\ %{}) do
    %HourlyObsData{}
    |> HourlyObsData.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a hourly_obs_data.

  ## Examples

      iex> update_hourly_obs_data(hourly_obs_data, %{field: new_value})
      {:ok, %HourlyObsData{}}

      iex> update_hourly_obs_data(hourly_obs_data, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_hourly_obs_data(%HourlyObsData{} = hourly_obs_data, attrs) do
    hourly_obs_data
    |> HourlyObsData.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a hourly_obs_data.

  ## Examples

      iex> delete_hourly_obs_data(hourly_obs_data)
      {:ok, %HourlyObsData{}}

      iex> delete_hourly_obs_data(hourly_obs_data)
      {:error, %Ecto.Changeset{}}

  """
  def delete_hourly_obs_data(%HourlyObsData{} = hourly_obs_data) do
    Repo.delete(hourly_obs_data)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking hourly_obs_data changes.

  ## Examples

      iex> change_hourly_obs_data(hourly_obs_data)
      %Ecto.Changeset{data: %HourlyObsData{}}

  """
  def change_hourly_obs_data(%HourlyObsData{} = hourly_obs_data, attrs \\ %{}) do
    HourlyObsData.changeset(hourly_obs_data, attrs)
  end

  defmacro array_agg(field) do
    quote do: fragment("array_agg(?)", unquote(field))
  end

  def get_current_information_for_aqi(source_id, foci_id) do
    foci = Cfg.get_foci!(foci_id)

    # not great but I flailed a bit here for a few days and I want to get this done and didn't figure out array_agg
    q =
      from hod in HourlyObsData,
        where: hod.source_id == ^source_id,
        limit: 1,
        order_by: {:asc, st_distance(hod.point, ^foci.place)}

    res = Repo.one(q)
    [res]
  end

  alias RoomSanctum.Storage.ICalendar

  @doc """
  Returns the list of calendar_entries.

  ## Examples

      iex> list_calendar_entries()
      [%Calendar{}, ...]

  """
  def list_icalendar_entries do
    Repo.all(ICalendar)
  end

  @doc """
  Gets a single calendar.

  Raises `Ecto.NoResultsError` if the Calendar does not exist.

  ## Examples

      iex> get_calendar!(123)
      %Calendar{}

      iex> get_calendar!(456)
      ** (Ecto.NoResultsError)

  """
  def get_icalendar!(id), do: Repo.get!(ICalendar, id)

  @doc """
  Creates a calendar.

  ## Examples

      iex> create_calendar(%{field: value})
      {:ok, %Calendar{}}

      iex> create_calendar(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_icalendar(attrs \\ %{}) do
    %ICalendar{}
    |> ICalendar.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a calendar.

  ## Examples

      iex> update_calendar(calendar, %{field: new_value})
      {:ok, %Calendar{}}

      iex> update_calendar(calendar, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_icalendar(%ICalendar{} = calendar, attrs) do
    calendar
    |> ICalendar.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a calendar.

  ## Examples

      iex> delete_calendar(calendar)
      {:ok, %Calendar{}}

      iex> delete_calendar(calendar)
      {:error, %Ecto.Changeset{}}

  """
  def delete_icalendar(%ICalendar{} = calendar) do
    Repo.delete(calendar)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking calendar changes.

  ## Examples

      iex> change_calendar(calendar)
      %Ecto.Changeset{data: %Calendar{}}

  """
  def change_icalendar(%ICalendar{} = calendar, attrs \\ %{}) do
    ICalendar.changeset(calendar, attrs)
  end

  alias RoomSanctum.Configuration

  def get_upcoming_calendar_entries(source_id, query) do
    foci = Configuration.get_foci!(query.foci_id)
    {lat, lon} = foci.place.coordinates
    tz = WhereTZ.lookup(lat, lon)
    # todo make this configurable from somewhere
    now = DateTime.new!(Date.utc_today(), Time.new!(0, 0, 0), tz)
    max = now |> DateTime.add(query.days * 24 * 60 * 60, :second)

    q =
      from ic in ICalendar,
        where: ic.source_id == ^source_id and ic.date_start >= ^now and ic.date_start <= ^max,
        order_by: [asc: ic.date_start],
        limit: ^query.limit

    Repo.all(q)
  end
end
