defmodule RoomSanctum.Storage do
  @moduledoc """
  The Storage context.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  alias RoomSanctum.Repo
  alias RoomSanctum.Configuration

  alias RoomSanctum.Storage.GTFS.Agency
  alias RoomSanctum.Storage.GBFS.V1.StationInfo

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

  # A GTFS import deletes a whole feed before reloading it, and gtfs_stop_times
  # runs to a couple of million rows per source. Ecto's default 15s is not
  # nearly enough for that delete on a database that is doing anything else,
  # and when it is exceeded the error blames the pool --
  # "client ... timed out because it queued and checked out the connection for
  # longer than 15000ms" -- which reads like connection starvation rather than
  # a statement that simply needed longer than a quarter of a minute.
  #
  # Only the GTFS truncates carry this. The GBFS ones below delete hundreds of
  # rows, not millions, and a query there running past 15s means something is
  # wrong rather than something is big.
  @gtfs_truncate_timeout :timer.minutes(15)

  def truncate_agency(source_id) do
    from(p in Agency, where: p.source_id == ^source_id)
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
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

  def list_calendars(source_id) do
    from(p in Calendar, where: p.source_id == ^source_id)
    |> Repo.all()
  end

  def count_calendars(source_id) do
    Repo.one(from p in Calendar, where: p.source_id == ^source_id, select: count(p.id))
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
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
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

  alias RoomSanctum.Storage.GTFS.CalendarDate

  @doc """
  The service exceptions for a source -- calendar_dates.txt.

  For several feeds this is not a footnote to calendar.txt but the greater part
  of the service definition: MBTA's bus services carry seven zero weekday flags
  and name every day they run here instead.
  """
  def count_calendar_dates(source_id) do
    Repo.one(from p in CalendarDate, where: p.source_id == ^source_id, select: count(p.id))
  end

  def truncate_calendar_date(source_id) do
    from(p in CalendarDate, where: p.source_id == ^source_id)
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
  end

  def change_calendar_date(%CalendarDate{} = calendar_date, attrs \\ %{}) do
    CalendarDate.changeset(calendar_date, attrs)
  end

  @doc """
  How many of a source's trips run on a service neither calendar file mentions.

  These are the trips the arrival filter keeps rather than hides, on the
  grounds that not knowing when something runs is not the same as knowing it
  does not. A large number here means the filter is mostly not filtering, which
  is worth being able to see rather than infer from a board that looks wrong.
  """
  def count_trips_without_service(source_id) do
    # Fully qualified: the Trip alias is introduced further down the file, and
    # `from` does not resolve the module until this runs -- so the short name
    # compiles here and fails at the first call.
    from(t in RoomSanctum.Storage.GTFS.Trip,
      as: :trip,
      where: t.source_id == ^source_id,
      where:
        not exists(
          from(c in Calendar,
            where:
              c.source_id == parent_as(:trip).source_id and
                c.service_id == parent_as(:trip).service_id,
            select: 1
          )
        ),
      where:
        not exists(
          from(cd in CalendarDate,
            where:
              cd.source_id == parent_as(:trip).source_id and
                cd.service_id == parent_as(:trip).service_id,
            select: 1
          )
        ),
      select: count(t.id)
    )
    |> Repo.one()
  end

  @doc """
  The service ids running on a date, as a MapSet.

  Both halves of the answer: the services whose calendar.txt row covers the
  date and names that weekday, plus the ones added for it by exception, minus
  the ones removed for it. A service can be defined entirely by exceptions --
  every weekday flag zero -- so neither half alone is the answer.
  """
  def services_on(source_id, %Date{} = date) do
    weekday = Date.day_of_week(date)

    scheduled =
      from(c in Calendar,
        where:
          c.source_id == ^source_id and c.start_date <= ^date and c.end_date >= ^date and
            field(c, ^weekday_field(weekday)) == 1,
        select: c.service_id
      )
      |> Repo.all()

    exceptions =
      from(cd in CalendarDate,
        where: cd.source_id == ^source_id and cd.date == ^date,
        select: {cd.service_id, cd.exception_type}
      )
      |> Repo.all()

    added = for {id, t} <- exceptions, t == 1, do: id
    removed = for {id, t} <- exceptions, t == 2, do: id

    scheduled
    |> MapSet.new()
    |> MapSet.union(MapSet.new(added))
    |> MapSet.difference(MapSet.new(removed))
  end

  defp weekday_field(1), do: :monday
  defp weekday_field(2), do: :tuesday
  defp weekday_field(3), do: :wednesday
  defp weekday_field(4), do: :thursday
  defp weekday_field(5), do: :friday
  defp weekday_field(6), do: :saturday
  defp weekday_field(7), do: :sunday

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

  def list_directions(source_id) do
    from(p in Direction, where: p.source_id == ^source_id)
    |> Repo.all()
  end

  def count_directions(source_id) do
    Repo.one(from p in Direction, where: p.source_id == ^source_id, select: count(p.id))
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
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
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
  alias RoomSanctum.Storage.GTFS.Shape

  @doc """
  Returns the list of routes.

  ## Examples

      iex> list_routes()
      [%Route{}, ...]

  """
  def list_routes do
    Repo.all(Route)
  end

  def list_routes(source_id) do
    from(p in Route, where: p.source_id == ^source_id)
    |> Repo.all()
  end

  @doc """
  Attach route, destination, direction and mode to realtime vehicle positions.

  A position names a route and a trip and nothing else, so everything a marker
  says comes from the static feed -- looked up only for the trips currently on
  screen, which is tens of rows rather than the whole table.
  """
  def with_trip_context([], _source_id), do: []

  def with_trip_context(vehicles, source_id) do
    by_trip =
      vehicles
      |> Enum.map(&Map.get(&1, :trip_id))
      |> Enum.reject(&is_nil/1)
      |> then(&vehicle_context(source_id, &1))

    # Realtime feeds run trips the schedule does not have -- shuttles and
    # added trips -- but they still name a route the schedule knows. On MBTA
    # that is about one vehicle in eight, which would otherwise show nothing
    # at all rather than at least which route it is on.
    by_route =
      vehicles
      |> Enum.reject(&Map.has_key?(by_trip, Map.get(&1, :trip_id)))
      |> Enum.map(&Map.get(&1, :route_id))
      |> Enum.reject(&is_nil/1)
      |> then(&route_context(source_id, &1))

    Enum.map(vehicles, fn vehicle ->
      context =
        Map.get(by_trip, Map.get(vehicle, :trip_id)) ||
          Map.get(by_route, Map.get(vehicle, :route_id)) ||
          %{}

      Map.merge(vehicle, context)
    end)
  end

  @doc """
  Route name and mode by route_id, for vehicles whose trip is not in the feed.
  """
  def route_context(_source_id, []), do: %{}

  def route_context(source_id, route_ids) do
    Repo.query!(
      """
      SELECT r.route_id,
             COALESCE(NULLIF(BTRIM(r.route_short_name), ''), r.route_long_name, r.route_id),
             r.route_type,
             r.route_color,
             r.route_text_color
      FROM gtfs_routes r
      WHERE r.source_id = $1 AND r.route_id = ANY($2)
      """,
      [source_id, Enum.uniq(route_ids)]
    ).rows
    |> Map.new(fn [route_id, route, route_type, color, text_color] ->
      {route_id,
       %{
         route: route,
         dest: nil,
         direction: nil,
         mode: mode_label(route_type),
         color: route_color(color),
         text_color: route_color(text_color)
       }}
    end)
  end

  @doc """
  Context for the trips a set of vehicles is running, keyed by trip_id:
  `%{route:, dest:, direction:, mode:}`.

  A realtime vehicle position carries only ids -- the route it is on and the
  trip it is running -- so everything a human wants to read comes from the
  static feed.
  """
  def vehicle_context(_source_id, []), do: %{}

  def vehicle_context(source_id, trip_ids) do
    Repo.query!(
      """
      SELECT t.trip_id,
             COALESCE(NULLIF(BTRIM(r.route_short_name), ''), r.route_long_name, r.route_id),
             NULLIF(BTRIM(t.trip_headsign), ''),
             d.direction,
             r.route_type,
             r.route_color,
             r.route_text_color
      FROM gtfs_trips t
      JOIN gtfs_routes r ON r.source_id = t.source_id AND r.route_id = t.route_id
      LEFT JOIN gtfs_directions d
             ON d.source_id = t.source_id
            AND d.route_id = t.route_id
            AND d.direction_id = t.direction_id
      WHERE t.source_id = $1 AND t.trip_id = ANY($2)
      """,
      [source_id, Enum.uniq(trip_ids)]
    ).rows
    |> Map.new(fn [trip_id, route, dest, direction, route_type, color, text_color] ->
      {trip_id,
       %{
         route: route,
         dest: dest,
         direction: direction,
         mode: mode_label(route_type),
         color: route_color(color),
         text_color: route_color(text_color)
       }}
    end)
  end

  # GTFS route_type as something worth showing a person. Anything outside the
  # spec's list is left alone rather than guessed at.
  defp mode_label(nil), do: nil

  defp mode_label(route_type) do
    case to_string(route_type) do
      "0" -> "Tram"
      "1" -> "Subway"
      "2" -> "Rail"
      "3" -> "Bus"
      "4" -> "Ferry"
      "5" -> "Cable tram"
      "6" -> "Aerial lift"
      "7" -> "Funicular"
      "11" -> "Trolleybus"
      "12" -> "Monorail"
      other -> other
    end
  end

  @doc """
  The routes that call at a stop, as a list of route_ids.

  Backed by the (source_id, stop_id) index on stop_times -- without it the
  planner walks every trip in the feed.
  """
  def routes_serving_stop(source_id, stop_id) do
    Repo.query!(
      """
      SELECT DISTINCT t.route_id
      FROM gtfs_stop_times st
      JOIN gtfs_trips t ON t.source_id = st.source_id AND t.trip_id = st.trip_id
      WHERE st.source_id = $1 AND st.stop_id = $2
      """,
      [source_id, stop_id]
    ).rows
    |> Enum.map(&List.first/1)
  end

  @doc """
  route_id => route_type for one source.

  Realtime vehicle positions carry only a route_id, but what a vehicle *is* --
  bus, tram, ferry -- lives on the route, so callers resolve it once and carry
  the map rather than querying per vehicle.
  """
  def route_types(source_id) do
    from(r in Route,
      where: r.source_id == ^source_id,
      select: {r.route_id, r.route_type}
    )
    |> Repo.all()
    |> Map.new()
  end

  # A drawn shape can run to a thousand points; at the weight these are
  # rendered, far fewer is indistinguishable and keeps the payload sane when a
  # feed has hundreds of routes.
  @max_line_points 200

  @doc """
  One polyline per route: `[%{id:, color:, points: [[lat, lng], ...]}]`.

  Uses shapes.txt where the feed ships it, which is the real drawn alignment.
  Routes with no shape fall back to the ordered stops of a representative trip
  -- straight hops between stops rather than following the road, but better
  than nothing on feeds that omit shapes.
  """
  def list_route_lines(source_ids) when is_list(source_ids) do
    source_ids
    |> Enum.uniq()
    |> Enum.flat_map(fn source_id ->
      # route_id is only unique within a feed, so the map would otherwise get
      # two lines claiming the same DOM id.
      source_id
      |> list_route_lines()
      |> Enum.map(fn line -> %{line | id: "#{source_id}-#{line.id}"} end)
    end)
  end

  def list_route_lines(source_id) do
    shaped = shaped_route_lines(source_id)
    covered = MapSet.new(shaped, & &1.id)

    uncovered =
      from(r in Route, where: r.source_id == ^source_id, select: r.route_id)
      |> Repo.all()
      |> Enum.reject(&MapSet.member?(covered, &1))

    # The stop-sequence fallback reads stop_times, which runs to millions of
    # rows; it is only worth paying for the routes shapes did not cover, and
    # on a feed with complete shapes that is none of them.
    shaped ++ stop_route_lines(source_id, uncovered)
  end

  defp shaped_route_lines(source_id) do
    Repo.query!(
      """
      WITH rep AS (
        SELECT DISTINCT ON (t.route_id) t.route_id, t.shape_id
        FROM gtfs_trips t
        WHERE t.source_id = $1 AND t.shape_id IS NOT NULL AND t.shape_id <> ''
        ORDER BY t.route_id, t.shape_id
      )
      SELECT r.route_id, r.route_color, sh.shape_pt_lat, sh.shape_pt_lon
      FROM rep
      JOIN gtfs_routes r ON r.source_id = $1 AND r.route_id = rep.route_id
      JOIN gtfs_shapes sh ON sh.source_id = $1 AND sh.shape_id = rep.shape_id
      WHERE sh.shape_pt_lat IS NOT NULL AND sh.shape_pt_lon IS NOT NULL
      ORDER BY r.route_id, sh.shape_pt_sequence
      """,
      [source_id]
    )
    |> rows_to_lines()
  end

  defp stop_route_lines(_source_id, []), do: []

  defp stop_route_lines(source_id, route_ids) do
    Repo.query!(
      """
      WITH rep AS (
        SELECT DISTINCT ON (t.route_id) t.route_id, t.trip_id
        FROM gtfs_trips t
        WHERE t.source_id = $1 AND t.route_id = ANY($2)
        ORDER BY t.route_id, t.trip_id
      )
      SELECT r.route_id, r.route_color, s.stop_lat, s.stop_lon
      FROM rep
      JOIN gtfs_routes r      ON r.source_id = $1 AND r.route_id = rep.route_id
      JOIN gtfs_stop_times st ON st.source_id = $1 AND st.trip_id = rep.trip_id
      JOIN gtfs_stops s       ON s.source_id = $1 AND s.stop_id = st.stop_id
      WHERE s.stop_lat IS NOT NULL AND s.stop_lon IS NOT NULL
      ORDER BY r.route_id, st.stop_sequence
      """,
      [source_id, route_ids]
    )
    |> rows_to_lines()
  end

  defp rows_to_lines(%{rows: rows}) do
    rows
    |> Enum.group_by(fn [route_id, _color, _lat, _lon] -> route_id end)
    |> Enum.map(fn {route_id, grouped} ->
      [[_, color, _, _] | _] = grouped

      %{
        id: route_id,
        color: route_color(color),
        points: grouped |> Enum.map(fn [_, _, lat, lon] -> [lat, lon] end) |> decimate()
      }
    end)
    # A single point is not a line, and a route with no usable geometry is noise.
    |> Enum.filter(&(length(&1.points) > 1))
  end

  # Every nth point, with the last one always kept so the line does not stop
  # short of where the route actually ends.
  defp decimate(points) do
    case length(points) do
      n when n <= @max_line_points ->
        points

      n ->
        step = div(n, @max_line_points) + 1

        kept =
          points
          |> Enum.with_index()
          |> Enum.filter(fn {_point, index} -> rem(index, step) == 0 end)
          |> Enum.map(&elem(&1, 0))

        last = List.last(points)
        if List.last(kept) == last, do: kept, else: kept ++ [last]
    end
  end

  # GTFS stores route_color bare ("FFC72C"); CSS needs the hash.
  defp route_color(nil), do: nil
  defp route_color(""), do: nil
  defp route_color("#" <> _ = color), do: color
  defp route_color(color), do: "#" <> color

  def count_routes(source_id) do
    Repo.one(from p in Route, where: p.source_id == ^source_id, select: count(p.id))
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

  def truncate_shape(source_id) do
    from(p in Shape, where: p.source_id == ^source_id)
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
  end

  def count_shapes(source_id) do
    from(p in Shape, where: p.source_id == ^source_id, select: count(p.id))
    |> Repo.one()
  end

  def truncate_route(source_id) do
    from(p in Route, where: p.source_id == ^source_id)
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
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

  def list_stop_times(source_id) do
    from(p in StopTime, where: p.source_id == ^source_id)
    |> Repo.all()
  end

  def count_stop_times(source_id) do
    Repo.one(from p in StopTime, where: p.source_id == ^source_id, select: count(p.id))
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
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
  end

  defp convert_gtfs_time(time) do
    [hour, min, second] = time |> String.split(":")
    hour = hour |> String.strip() |> String.to_integer()

    hour =
      cond do
        hour >= 24 -> hour - 24
        true -> hour
      end

    hourzf = hour |> Integer.to_string() |> String.pad_leading(2, "0")
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

  def list_stops(source_id) do
    from(p in Stop, where: p.source_id == ^source_id)
    |> Repo.all()
  end

  def list_stops(source_id, search_term) do
    from(p in Stop,
      where:
        p.source_id == ^source_id and
          fragment(
            "searchable @@ websearch_to_tsquery(?)",
            ^search_term
          ),
      order_by: {
        :desc,
        fragment(
          "ts_rank_cd(searchable, websearch_to_tsquery(?), 4)",
          ^search_term
        )
      }
    )
    |> Repo.all()
  end

  def count_stops(source_id) do
    Repo.one(from p in Stop, where: p.source_id == ^source_id, select: count(p.id))
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
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
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

  def get_stop_by_id(source_id, stop_id) do
    from(s in Stop,
      where: s.source_id == ^source_id and s.stop_id == ^stop_id,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  The stops a list of ids names, as `stop_id => stop`.

  One query for the lot. Realtime track assignments arrive as stop ids and are
  resolved together, rather than a round trip per arrival on a board that may
  be showing thirty of them.
  """
  def get_stops_by_ids(_source_id, []), do: %{}

  def get_stops_by_ids(source_id, stop_ids) do
    from(s in Stop,
      where: s.source_id == ^source_id and s.stop_id in ^stop_ids
    )
    |> Repo.all()
    |> Map.new(fn s -> {s.stop_id, s} end)
  end

  def get_gbfs_station_by_id(source_id, station_id) do
    from(s in StationInfo,
      where: s.source_id == ^source_id and s.station_id == ^stringify(station_id),
      limit: 1
    )
    |> Repo.one()
  end

  def get_foci_by_id(foci_id) do
    Configuration.get_foci!(foci_id)
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

  def list_trips(source_id) do
    from(p in Trip, where: p.source_id == ^source_id)
    |> Repo.all()
  end

  def count_trips(source_id) do
    Repo.one(from p in Trip, where: p.source_id == ^source_id, select: count(p.id))
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
    |> Repo.delete_all(timeout: @gtfs_truncate_timeout)
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

  # Get trips that serve a specific stop
  def get_trips_for_stop(source_id, stop_id) do
    from(st in StopTime,
      join: t in Trip,
      on: st.trip_id == t.trip_id,
      where: st.source_id == ^source_id and 
             t.source_id == ^source_id and
             st.stop_id == ^stop_id,
      select: t,
      distinct: true
    )
    |> Repo.all()
  end

  alias RoomSanctum.Configuration, as: Cfg

  defp stringify(val) when is_integer(val) do
    val
    |> Integer.to_string()
  end

  defp stringify(val) do
    val
  end

  @doc false
  # Keep only the trips whose service actually runs on `date`, and be careful
  # about what "actually" can be known.
  #
  # A stop's timetable holds every service pattern the feed publishes --
  # weekday, Saturday, Sunday, and on MBTA a dozen dated variants of each -- so
  # without this the board is mostly departures that will not happen, and the
  # limit is spent on them. One stop there mixes twelve patterns.
  #
  # Two things stop this from being a filter that empties boards, and both are
  # load-bearing rather than defensive dressing. Measured on the dev database,
  # two of eight sources have no usable service data at all: one has 33,163
  # trips and not a single calendar row, another has calendars that expired
  # days ago.
  #
  #   * A service nothing says anything about is kept. Neither file mentioning
  #     it means we do not know when it runs, and hiding it asserts something
  #     we have not been told.
  #
  #   * A source with nothing running today is not filtered at all. That is a
  #     feed whose service data has gone stale, and a board of possibly-wrong
  #     times beats a blank one.
  defp running_on(queryable, source_id, date) do
    weekday = weekday_column(Date.day_of_week(date))

    scheduled =
      "gtfs_calendars"
      |> where([c], c.source_id == ^source_id and c.start_date <= ^date and c.end_date >= ^date)
      |> where([c], field(c, ^weekday) == 1)

    exception = fn type ->
      "gtfs_calendar_dates"
      |> where([cd], cd.source_id == ^source_id and cd.date == ^date and cd.exception_type == ^type)
    end

    from([st, trip: t] in queryable,
      where:
        (exists(from(c in scheduled, where: c.service_id == parent_as(:trip).service_id, select: 1)) or
           exists(
             from(cd in exception.(1), where: cd.service_id == parent_as(:trip).service_id, select: 1)
           ) or
           not exists(
             from(c in "gtfs_calendars",
               where: c.source_id == ^source_id and c.service_id == parent_as(:trip).service_id,
               select: 1
             )
           ) and
             not exists(
               from(cd in "gtfs_calendar_dates",
                 where: cd.source_id == ^source_id and cd.service_id == parent_as(:trip).service_id,
                 select: 1
               )
             ) or
           not exists(from(c in scheduled, select: 1)) and
             not exists(from(cd in exception.(1), select: 1))) and
          not exists(
            from(cd in exception.(2), where: cd.service_id == parent_as(:trip).service_id, select: 1)
          )
    )
  end

  defp weekday_column(1), do: :monday
  defp weekday_column(2), do: :tuesday
  defp weekday_column(3), do: :wednesday
  defp weekday_column(4), do: :thursday
  defp weekday_column(5), do: :friday
  defp weekday_column(6), do: :saturday
  defp weekday_column(7), do: :sunday

  defp conditional_where(queryable, source_id, stop_id, timestamp_time_hour, timestamp_time) do
#    case timestamp_time < timestamp_time_hour do
#      true ->
        where(
          queryable,
          [st],
          st.source_id == ^source_id and st.arrival_time >= ^time_to_interval(timestamp_time) and
            st.arrival_time <= ^time_to_interval(timestamp_time_hour) and st.stop_id == ^stringify(stop_id)
        )

#      false ->
#        where(
#          queryable,
#          [st],
#          st.source_id == ^source_id and
#            ((st.arrival_time >= ^timestamp_time and st.arrival_time <= ^Time.new!(23, 59, 50)) or
#               (^Time.new!(0, 0, 0) <= st.arrival_time and st.arrival_time <= ^timestamp_time_hour)) and
#            st.stop_id == ^stringify(stop_id)
#        )
#    end
  end

  defp divrem(num, den) do
    {div(num, den), rem(num, den)}
  end

  def time_to_interval(time) do
    as_interval =
      if time.hour < 5 do
        %{hours: time.hour + 24, minutes: time.minute, seconds: time.second}
      else
        %{hours: time.hour, minutes: time.minute, seconds: time.second}
      end
    as_seconds = as_interval.hours * 60 * 60 + as_interval.minutes * 60 + as_interval.seconds
    struct(Postgrex.Interval, %{secs: as_seconds})
  end

  def interval_to_time(interval) do
    {h, r1} = divrem(interval, (60*60))
    {m, s} = divrem(r1, 60)
    h = if h > 23 do
      h - 24
      else
      h
    end
    Time.new!(h,m,s)
  end

  def fix_arrival_times(res) do
    res |> Enum.map(fn map -> map |> Map.put(:arrival_time, map.arrival_time.secs |> interval_to_time) end)
  end

  def get_all_arrivals_for_stop(source_id, stop_id) do

  end

  @doc """
  The next arrivals at a stop, in the stop's own timezone.

  `tz` is the source's, and the caller usually has it already -- the GTFS
  worker holds the source in its state and has just read it again to decide
  whether the feed has realtime. Looking it up here as well cost three more
  queries per call, because `get_source!/1` preloads mailboxes and webhooks
  onto a row we want one field from. Passing it in skips all of that; leaving
  it out still works, and still pays for it.
  """
  def get_upcoming_arrivals_for_stop(source_id, stop_id, limit \\ 16, timestamp \\ :now, tz \\ nil)

  def get_upcoming_arrivals_for_stop(source_id, stop_id, limit, timestamp, nil) do
    get_upcoming_arrivals_for_stop(
      source_id,
      stop_id,
      limit,
      timestamp,
      Cfg.get_source!(source_id).config.tz
    )
  end

  def get_upcoming_arrivals_for_stop(source_id, stop_id, limit, timestamp, tz) do
    timestamp =
      case timestamp do
        :now -> DateTime.now!(tz)
        _ -> timestamp
      end

    timestamp_time =
      timestamp
      |> DateTime.to_time()

    timestamp_time_hour = timestamp |> DateTime.add(60 * 60) |> DateTime.to_time()

    StopTime
    |> conditional_where(source_id, stop_id, timestamp_time_hour, timestamp_time)
    |> order_by([st], asc: st.arrival_time)
    |> limit(^limit)
    # Every join carries source_id, and not only because a trip_id is unique
    # within a feed rather than across them -- 3,491 stop_ids, 438 route_ids
    # and 185 trip_ids are shared by two feeds in the dev database, so without
    # it a stop's arrivals pick up another agency's routes and calendars, and
    # one arrival comes back several times over. It is also the whole of the
    # performance story: every unique index on these tables leads with
    # source_id, so joining on the bare id can use none of them, and matching
    # a stop's arrivals meant a sequential scan of gtfs_trips -- 271k rows --
    # hashed afresh on every request.
    |> join(:left, [st], s in Stop,
      as: :stop,
      on: s.stop_id == st.stop_id and s.source_id == st.source_id
    )
    |> join(:left, [st], t in Trip,
      as: :trip,
      on: t.trip_id == st.trip_id and t.source_id == st.source_id
    )
    |> running_on(source_id, DateTime.to_date(timestamp))
    |> join(:left, [st, trip: t], r in Route,
      as: :route,
      on: t.route_id == r.route_id and r.source_id == st.source_id
    )
    |> join(:left, [st, trip: t], d in Direction,
      as: :direction,
      on:
        t.direction_id == d.direction_id and t.route_id == d.route_id and
          d.source_id == st.source_id
    )
    |> join(:left, [st, trip: t], c in Calendar,
      as: :calendar,
      on: t.service_id == c.service_id and c.source_id == st.source_id
    )
    |> select(
      [st, s, t, r, d, c],
      #          [c,d,r,t,s,st],
      #        [st,:stop,:trip,:route,:direction,:calendar],
      %{
        arrival_time: st.arrival_time,
        arrival_time_live_ts: nil,
        arrival_time_live_delay: nil,
        arrival_time_live_uncertianty: nil,
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
        },
        tz: ^tz
      }
    )
    |> Repo.all()

    #    q =
    #      from st in StopTime,
    #        where: st.source_id == ^source_id and st.arrival_time >= ^timestamp_time and st.arrival_time <= ^timestamp_time_hour and st.stop_id == ^stringify(stop_id),
    #        order_by: [
    #          asc: st.arrival_time
    #        ],
    #        limit: ^limit,
    #        left_join: s in Stop,
    #        on: s.stop_id == st.stop_id,
    #        left_join: t in Trip,
    #        on: t.trip_id == st.trip_id,
    #        left_join: r in Route,
    #        on: t.route_id == r.route_id,
    #        left_join: d in Direction,
    #        on: t.direction_id == d.direction_id and t.route_id == d.route_id,
    #        left_join: c in Calendar,
    #        on: t.service_id == c.service_id,
    #        select: %{
    #          arrival_time: st.arrival_time,
    #          arrival_time_live_ts: nil,
    #          arrival_time_live_delay: nil,
    #          arrival_time_live_uncertianty: nil,
    #          departure_time: st.departure_time,
    #          stop_id: st.stop_id,
    #          stop_sequence: st.stop_sequence,
    #          stop: %{
    #            stop_address: s.stop_address,
    #            stop_code: s.stop_code,
    #            stop_desc: s.stop_desc,
    #            stop_id: s.stop_id,
    #            stop_lat: s.stop_lat,
    #            stop_lon: s.stop_lon,
    #            stop_name: s.stop_name,
    #            stop_url: s.stop_url
    #          },
    #          trip_id: st.trip_id,
    #          trip: %{
    #            bikes_allowed: t.bikes_allowed,
    #            direction_id: t.direction_id,
    #            direction: %{
    #              direction: d.direction,
    #              direction_id: d.direction_id
    #            },
    #            route_id: t.route_id,
    #            route: %{
    #              line_id: r.line_id,
    #              route_color: r.route_color,
    #              route_desc: r.route_desc,
    #              route_fare_class: r.route_fare_class,
    #              route_id: r.route_id,
    #              route_long_name: r.route_long_name,
    #              route_short_name: r.route_short_name,
    #              route_sort_order: r.route_sort_order,
    #              route_text_color: r.route_text_color,
    #              route_type: r.route_type,
    #              route_url: r.route_url
    #            },
    #            service_id: t.service_id,
    #            service: %{
    #              service_id: c.service_id,
    #              service_name: c.service_name,
    #              start_date: c.start_date,
    #              end_date: c.end_date,
    #              monday: c.monday,
    #              tuesday: c.tuesday,
    #              wednesday: c.wednesday,
    #              thursday: c.thursday,
    #              friday: c.friday,
    #              saturday: c.saturday,
    #              sunday: c.sunday
    #            },
    #            trip_headsign: t.trip_headsign,
    #            trip_id: t.trip_id,
    #            trip_short_name: t.trip_short_name
    #          },
    #          tz: ^tz
    #        }
    #
    #    Repo.all(q)
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

  def get_sys_info!(:src, source_id) do
    from(s in SysInfo, where: s.source_id == ^source_id)
    |> Repo.one()
  end

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

  @doc """
  Returns the list of gbfs_station_information.

  ## Examples

      iex> list_gbfs_station_information()
      [%StationInfo{}, ...]

  """
  def list_gbfs_station_information do
    Repo.all(StationInfo)
  end

  def list_gbfs_station_information(source_id) do
    from(s in StationInfo,
      where: s.source_id == ^source_id
    )
    |> Repo.all()
  end

  def list_gbfs_station_information(source_id, search_term) do
    from(p in StationInfo,
      where:
        p.source_id == ^source_id and
          fragment(
            "searchable @@ websearch_to_tsquery(?)",
            ^search_term
          ),
      order_by: {
        :desc,
        fragment(
          "ts_rank_cd(searchable, websearch_to_tsquery(?), 4)",
          ^search_term
        )
      }
    )
    |> Repo.all()
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

  def list_gbfs_station_status(source_id) do
    from(s in StationStatus,
      where: s.source_id == ^source_id
    )
    |> Repo.all()
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


  alias RoomSanctum.Storage.GBFS.V1.EbikesAtStations

  @doc """
  Returns the list of gbfs_ebikes_stations.

  ## Examples

      iex> list_gbfs_ebikes_stations()
      [%EbikesAtStations{}, ...]

  """
  def list_gbfs_ebikes_stations do
    Repo.all(EbikesAtStations)
  end

  @doc """
  Gets a single ebikes_at_stations.

  Raises `Ecto.NoResultsError` if the Ebikes at stations does not exist.

  ## Examples

      iex> get_ebikes_at_stations!(123)
      %EbikesAtStations{}

      iex> get_ebikes_at_stations!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ebikes_at_stations!(id), do: Repo.get!(EbikesAtStations, id)

  @doc """
  Creates a ebikes_at_stations.

  ## Examples

      iex> create_ebikes_at_stations(%{field: value})
      {:ok, %EbikesAtStations{}}

      iex> create_ebikes_at_stations(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ebikes_at_stations(attrs \\ %{}) do
    %EbikesAtStations{}
    |> EbikesAtStations.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ebikes_at_stations.

  ## Examples

      iex> update_ebikes_at_stations(ebikes_at_stations, %{field: new_value})
      {:ok, %EbikesAtStations{}}

      iex> update_ebikes_at_stations(ebikes_at_stations, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ebikes_at_stations(%EbikesAtStations{} = ebikes_at_stations, attrs) do
    ebikes_at_stations
    |> EbikesAtStations.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ebikes_at_stations.

  ## Examples

      iex> delete_ebikes_at_stations(ebikes_at_stations)
      {:ok, %EbikesAtStations{}}

      iex> delete_ebikes_at_stations(ebikes_at_stations)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ebikes_at_stations(%EbikesAtStations{} = ebikes_at_stations) do
    Repo.delete(ebikes_at_stations)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ebikes_at_stations changes.

  ## Examples

      iex> change_ebikes_at_stations(ebikes_at_stations)
      %Ecto.Changeset{data: %EbikesAtStations{}}

  """
  def change_ebikes_at_stations(%EbikesAtStations{} = ebikes_at_stations, attrs \\ %{}) do
    EbikesAtStations.changeset(ebikes_at_stations, attrs)
  end

  def truncate_ebikes_at_stations(source_id) do
    from(e in EbikesAtStations, where: e.source_id == ^source_id)
    |> Repo.delete_all()
  end

  alias RoomSanctum.Storage.GBFS.V1.FreeBikeStatus

  @doc """
  Returns the list of gbfs_free_bike_status.

  ## Examples

      iex> list_gbfs_free_bike_status()
      [%FreeBikeStatus{}, ...]

  """
  def list_gbfs_free_bike_status do
    Repo.all(FreeBikeStatus)
  end

  @doc """
  Gets a single free_bike_status.

  Raises `Ecto.NoResultsError` if the Free bike status does not exist.

  ## Examples

      iex> get_free_bike_status!(123)
      %FreeBikeStatus{}

      iex> get_free_bike_status!(456)
      ** (Ecto.NoResultsError)

  """
  def get_free_bike_status!(id), do: Repo.get!(FreeBikeStatus, id)

  @doc """
  Creates a free_bike_status.

  ## Examples

      iex> create_free_bike_status(%{field: value})
      {:ok, %FreeBikeStatus{}}

      iex> create_free_bike_status(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_free_bike_status(attrs \\ %{}) do
    %FreeBikeStatus{}
    |> FreeBikeStatus.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a free_bike_status.

  ## Examples

      iex> update_free_bike_status(free_bike_status, %{field: new_value})
      {:ok, %FreeBikeStatus{}}

      iex> update_free_bike_status(free_bike_status, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_free_bike_status(%FreeBikeStatus{} = free_bike_status, attrs) do
    free_bike_status
    |> FreeBikeStatus.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a free_bike_status.

  ## Examples

      iex> delete_free_bike_status(free_bike_status)
      {:ok, %FreeBikeStatus{}}

      iex> delete_free_bike_status(free_bike_status)
      {:error, %Ecto.Changeset{}}

  """
  def delete_free_bike_status(%FreeBikeStatus{} = free_bike_status) do
    Repo.delete(free_bike_status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking free_bike_status changes.

  ## Examples

      iex> change_free_bike_status(free_bike_status)
      %Ecto.Changeset{data: %FreeBikeStatus{}}

  """
  def change_free_bike_status(%FreeBikeStatus{} = free_bike_status, attrs \\ %{}) do
    FreeBikeStatus.changeset(free_bike_status, attrs)
  end

  def truncate_free_bike_status(source_id) do
    from(e in FreeBikeStatus, where: e.source_id == ^source_id)
    |> Repo.delete_all()
  end

  alias RoomSanctum.Storage.GBFS.V1.VehicleTypes

  @doc """
  Returns the list of gbfs_vehicle_types.

  ## Examples

      iex> list_gbfs_vehicle_types()
      [%VehicleTypes{}, ...]

  """
  def list_gbfs_vehicle_types do
    Repo.all(VehicleTypes)
  end

  @doc """
  Gets a single vehicle_types.

  Raises `Ecto.NoResultsError` if the Vehicle types does not exist.

  ## Examples

      iex> get_vehicle_types!(123)
      %VehicleTypes{}

      iex> get_vehicle_types!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vehicle_types!(id), do: Repo.get!(VehicleTypes, id)

  @doc """
  Creates a vehicle_types.

  ## Examples

      iex> create_vehicle_types(%{field: value})
      {:ok, %VehicleTypes{}}

      iex> create_vehicle_types(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vehicle_types(attrs \\ %{}) do
    %VehicleTypes{}
    |> VehicleTypes.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vehicle_types.

  ## Examples

      iex> update_vehicle_types(vehicle_types, %{field: new_value})
      {:ok, %VehicleTypes{}}

      iex> update_vehicle_types(vehicle_types, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vehicle_types(%VehicleTypes{} = vehicle_types, attrs) do
    vehicle_types
    |> VehicleTypes.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vehicle_types.

  ## Examples

      iex> delete_vehicle_types(vehicle_types)
      {:ok, %VehicleTypes{}}

      iex> delete_vehicle_types(vehicle_types)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vehicle_types(%VehicleTypes{} = vehicle_types) do
    Repo.delete(vehicle_types)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vehicle_types changes.

  ## Examples

      iex> change_vehicle_types(vehicle_types)
      %Ecto.Changeset{data: %VehicleTypes{}}

  """
  def change_vehicle_types(%VehicleTypes{} = vehicle_types, attrs \\ %{}) do
    VehicleTypes.changeset(vehicle_types, attrs)
  end

  def truncate_vehicle_types(source_id) do
    from(e in VehicleTypes, where: e.source_id == ^source_id)
    |> Repo.delete_all()
  end


  alias RoomSanctum.Storage.GBFS.V1.SystemPricingPlans

  @doc """
  Returns the list of gbfs_system_pricing_plans.

  ## Examples

      iex> list_gbfs_system_pricing_plans()
      [%SystemPricingPlans{}, ...]

  """
  def list_gbfs_system_pricing_plans do
    Repo.all(SystemPricingPlans)
  end

  @doc """
  Gets a single system_pricing_plans.

  Raises `Ecto.NoResultsError` if the System pricing plans does not exist.

  ## Examples

      iex> get_system_pricing_plans!(123)
      %SystemPricingPlans{}

      iex> get_system_pricing_plans!(456)
      ** (Ecto.NoResultsError)

  """
  def get_system_pricing_plans!(id), do: Repo.get!(SystemPricingPlans, id)

  @doc """
  Creates a system_pricing_plans.

  ## Examples

      iex> create_system_pricing_plans(%{field: value})
      {:ok, %SystemPricingPlans{}}

      iex> create_system_pricing_plans(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_system_pricing_plans(attrs \\ %{}) do
    %SystemPricingPlans{}
    |> SystemPricingPlans.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a system_pricing_plans.

  ## Examples

      iex> update_system_pricing_plans(system_pricing_plans, %{field: new_value})
      {:ok, %SystemPricingPlans{}}

      iex> update_system_pricing_plans(system_pricing_plans, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_system_pricing_plans(%SystemPricingPlans{} = system_pricing_plans, attrs) do
    system_pricing_plans
    |> SystemPricingPlans.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a system_pricing_plans.

  ## Examples

      iex> delete_system_pricing_plans(system_pricing_plans)
      {:ok, %SystemPricingPlans{}}

      iex> delete_system_pricing_plans(system_pricing_plans)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system_pricing_plans(%SystemPricingPlans{} = system_pricing_plans) do
    Repo.delete(system_pricing_plans)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking system_pricing_plans changes.

  ## Examples

      iex> change_system_pricing_plans(system_pricing_plans)
      %Ecto.Changeset{data: %SystemPricingPlans{}}

  """
  def change_system_pricing_plans(%SystemPricingPlans{} = system_pricing_plans, attrs \\ %{}) do
    SystemPricingPlans.changeset(system_pricing_plans, attrs)
  end

  def truncate_system_pricing_plans(source_id) do
    from(e in SystemPricingPlans, where: e.source_id == ^source_id)
    |> Repo.delete_all()
  end

  alias RoomSanctum.Storage.GBFS.V1.GeoFencingZones

  @doc """
  Returns the list of gbfs_geofencing_zones.

  ## Examples

      iex> list_gbfs_geofencing_zones()
      [%GeoFencingZones{}, ...]

  """
  def list_gbfs_geofencing_zones do
    Repo.all(GeoFencingZones)
  end

  @doc """
  Gets a single geo_fencing_zones.

  Raises `Ecto.NoResultsError` if the Geo fencing zones does not exist.

  ## Examples

      iex> get_geo_fencing_zones!(123)
      %GeoFencingZones{}

      iex> get_geo_fencing_zones!(456)
      ** (Ecto.NoResultsError)

  """
  def get_geo_fencing_zones!(id), do: Repo.get!(GeoFencingZones, id)

  @doc """
  Creates a geo_fencing_zones.

  ## Examples

      iex> create_geo_fencing_zones(%{field: value})
      {:ok, %GeoFencingZones{}}

      iex> create_geo_fencing_zones(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_geo_fencing_zones(attrs \\ %{}) do
    %GeoFencingZones{}
    |> GeoFencingZones.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a geo_fencing_zones.

  ## Examples

      iex> update_geo_fencing_zones(geo_fencing_zones, %{field: new_value})
      {:ok, %GeoFencingZones{}}

      iex> update_geo_fencing_zones(geo_fencing_zones, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_geo_fencing_zones(%GeoFencingZones{} = geo_fencing_zones, attrs) do
    geo_fencing_zones
    |> GeoFencingZones.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a geo_fencing_zones.

  ## Examples

      iex> delete_geo_fencing_zones(geo_fencing_zones)
      {:ok, %GeoFencingZones{}}

      iex> delete_geo_fencing_zones(geo_fencing_zones)
      {:error, %Ecto.Changeset{}}

  """
  def delete_geo_fencing_zones(%GeoFencingZones{} = geo_fencing_zones) do
    Repo.delete(geo_fencing_zones)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking geo_fencing_zones changes.

  ## Examples

      iex> change_geo_fencing_zones(geo_fencing_zones)
      %Ecto.Changeset{data: %GeoFencingZones{}}

  """
  def change_geo_fencing_zones(%GeoFencingZones{} = geo_fencing_zones, attrs \\ %{}) do
    GeoFencingZones.changeset(geo_fencing_zones, attrs)
  end

  def truncate_geo_fencing_zones(source_id) do
    from(e in GeoFencingZones, where: e.source_id == ^source_id)
    |> Repo.delete_all()
  end


  def get_current_information_for_bikestop(source_id, stop_id) do
    q =
      from st in StationStatus,
        where: st.source_id == ^source_id and st.station_id == ^stringify(stop_id),
        left_join: si in StationInfo,
        on: si.station_id == st.station_id and si.source_id == ^source_id,
        left_join: eb in EbikesAtStations,
        on: eb.station_id == st.station_id,
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
          short_name: si.short_name,
          ebikes_info: eb.ebikes
        }

    Repo.one(q)
  end

  def count_gbfs_stations(source_id) do
    from(s in StationInfo,
      where:
        s.source_id == ^source_id,
      select: fragment("count(*)")
    )
    |> Repo.one()
  end

  def count_gbfs_slots(source_id) do
    from(s in StationStatus,
      where:
        s.source_id == ^source_id,
      select: fragment("sum(abs(?))", s.num_docks_available)
    )
    |> Repo.one()
  end

  def count_gbfs_bikes(source_id) do
    from(s in StationStatus,
      where:
        s.source_id == ^source_id,
      select: fragment("sum(abs(?))", s.num_bikes_available)
    )
    |> Repo.one()
  end

  def count_gbfs_ebikes(source_id) do
    from(s in StationStatus,
      where:
        s.source_id == ^source_id,
      select: fragment("sum(abs(?))", s.num_ebikes_available)
    )
    |> Repo.one()
  end

  def count_free_bikes(source_id) do
    from(s in FreeBikeStatus,
      where:
        s.source_id == ^source_id,
      select: fragment("count(*)")
    )
    |> Repo.one()
  end

  def count_free_bikes_types(source_id) do
    from(s in FreeBikeStatus,
      where:
        s.source_id == ^source_id,
      join: vt in VehicleTypes,
      on: s.vehicle_type_id == vt.vehicle_type_id,
      group_by: vt.form_factor,
      select: %{cnt: count(s.vehicle_type_id), ff: vt.form_factor}
    )
    |> Repo.all()
  end

  @doc """
  A source's vehicle types, keyed by the id the feed refers to them by.

  One query for a list of bikes rather than one per bike: a feed publishes a
  handful of types and then points thousands of vehicles at them.
  """
  def gbfs_vehicle_types(source_id) do
    from(v in VehicleTypes, where: v.source_id == ^source_id)
    |> Repo.all()
    |> Map.new(fn type -> {type.vehicle_type_id, type} end)
  end

  @doc """
  Docking stations within `radius` metres of a foci, in the shape a station
  query answers with -- so the condenser, the preview cards and the map all
  read a dock found this way exactly as they read one asked for by id.

  Metres via geography, as free_bikes_near_foci/3.
  """
  def stations_near_foci(source_id, foci_id, radius) do
    case get_foci_by_id(foci_id) do
      %{place: %Geo.Point{} = place} ->
        from(st in StationStatus,
          join: si in StationInfo,
          on: si.station_id == st.station_id and si.source_id == st.source_id,
          left_join: eb in EbikesAtStations,
          on: eb.station_id == st.station_id,
          where:
            st.source_id == ^source_id and
              fragment("ST_DWithin(?::geography, ?::geography, ?)", si.place, ^place, ^radius),
          order_by: fragment("? <-> ?", si.place, ^place),
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
            short_name: si.short_name,
            ebikes_info: eb.ebikes
          }
        )
        |> Repo.all()

      _ ->
        []
    end
  end

  @doc """
  Free-floating bikes within `radius` metres of a foci.

  Metres, via a cast to geography: `point` is a plain 4326 geometry, and
  ST_DWithin on one of those measures in degrees -- a "500" meant as half a
  kilometre would be most of a continent. Foci have been stored {lon, lat}
  since they were normalised, so the point goes straight in.
  """
  def free_bikes_near_foci(source_id, foci_id, radius) do
    case get_foci_by_id(foci_id) do
      %{place: %Geo.Point{} = place} ->
        from(f in FreeBikeStatus,
          where:
            fragment("ST_DWithin(?::geography, ?::geography, ?)", f.point, ^place, ^radius) and
              f.source_id == ^source_id,
          order_by: fragment("? <-> ?", f.point, ^place)
        )
        |> Repo.all()

      _ ->
        []
    end
  end

  def find_free_bikes_around_point(source_id, point, distance) do
    from(f in FreeBikeStatus,
      where: fragment("ST_DWithin(?, ?, ?)", f.point, ^point, ^distance)
      and
      f.source_id == ^source_id,
    )
    |> Repo.all()
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
    case nearest_aqi_stations(source_id, foci_id, 1) do
      [] -> [nil]
      [station] -> [station]
    end
  end

  @doc """
  The monitoring stations nearest a foci, closest first.

  One row per station: the feed replaces the whole set each hour, so the
  current reading and the station itself are the same record.
  """
  def nearest_aqi_stations(source_id, foci_id, limit \\ 5) do
    foci = Cfg.get_foci!(foci_id)
    nearby_aqi_stations(source_id, foci.place, limit)
  end

  @doc """
  Monitoring stations nearest a point, closest first.

  Both geometries are {lon, lat}, so st_distance compares them directly --
  they used to be transposed in step with each other, which worked until one
  side was normalised.
  """
  def nearby_aqi_stations(source_id, %Geo.Point{} = point, limit \\ 5) do
    from(hod in HourlyObsData,
      where: hod.source_id == ^source_id and not is_nil(hod.point),
      limit: ^limit,
      order_by: {:asc, st_distance(hod.point, ^point)}
    )
    |> Repo.all()
  end

  def nearby_aqi_stations(_source_id, _point, _limit), do: []

  @doc """
  One named monitoring station, or an empty list if it is not reporting.
  """
  def get_aqi_station(source_id, aqsid) do
    from(hod in HourlyObsData,
      where: hod.source_id == ^source_id and hod.aqsid == ^aqsid,
      order_by: [desc: hod.valid_date, desc: hod.valid_time],
      limit: 1
    )
    |> Repo.all()
  end

  @doc """
  Every station currently reporting for a source.

  DISTINCT ON rather than a plain select, so this stays one row per station if
  the feed ever keeps more than the latest hour.
  """
  def list_aqi_stations(source_id) do
    from(hod in HourlyObsData,
      where: hod.source_id == ^source_id and not is_nil(hod.point),
      distinct: hod.aqsid,
      order_by: [asc: hod.aqsid, desc: hod.valid_date, desc: hod.valid_time]
    )
    |> Repo.all()
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
    {lon, lat} = foci.place.coordinates
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

  alias RoomSanctum.Storage.Taxidae

  @doc """
  Returns the list of storage_mail.

  ## Examples

      iex> list_storage_mail()
      [%Taxidae{}, ...]

  """
  def list_storage_mail do
    Repo.all(Taxidae)
  end

  @doc """
  Gets a single taxidae.

  Raises `Ecto.NoResultsError` if the Taxidae does not exist.

  ## Examples

      iex> get_taxidae!(123)
      %Taxidae{}

      iex> get_taxidae!(456)
      ** (Ecto.NoResultsError)

  """
  def get_taxidae!(id), do: Repo.get!(Taxidae, id)

  @doc """
  Creates a taxidae.

  ## Examples

      iex> create_taxidae(%{field: value})
      {:ok, %Taxidae{}}

      iex> create_taxidae(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_taxidae(attrs \\ %{}) do
    %Taxidae{}
    |> Taxidae.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a taxidae.

  ## Examples

      iex> update_taxidae(taxidae, %{field: new_value})
      {:ok, %Taxidae{}}

      iex> update_taxidae(taxidae, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_taxidae(%Taxidae{} = taxidae, attrs) do
    taxidae
    |> Taxidae.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a taxidae.

  ## Examples

      iex> delete_taxidae(taxidae)
      {:ok, %Taxidae{}}

      iex> delete_taxidae(taxidae)
      {:error, %Ecto.Changeset{}}

  """
  def delete_taxidae(%Taxidae{} = taxidae) do
    Repo.delete(taxidae)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking taxidae changes.

  ## Examples

      iex> change_taxidae(taxidae)
      %Ecto.Changeset{data: %Taxidae{}}

  """
  def change_taxidae(%Taxidae{} = taxidae, attrs \\ %{}) do
    Taxidae.changeset(taxidae, attrs)
  end
end
