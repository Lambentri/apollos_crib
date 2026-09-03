defmodule RoomSanctum.Worker.Plani do
  @moduledoc """
  A vision whose anchor moves.

  The same job the Vision worker does -- ask on a tick, hold the answers, hand
  them out -- with one thing in front of it: where to ask from. A Vision's
  queries name their own places. A Plani asks its sources around whichever
  client is reporting to it, and around its home foci when none is.

  The position is never written down. It is read from the Ankyra worker, which
  holds it in memory for a few minutes, and if that has expired the home foci
  answers instead. So a Plani has an anchor from the moment it is created,
  before any client has ever reported, and returns to one when a client stops.
  """
  use GenServer

  require Logger

  alias RoomSanctum.{Configuration, Storage}

  @registry :zeus

  # Long enough not to hammer the sources, short enough that a board is worth
  # reading while walking. The Vision worker's own tick is the precedent.
  @tick_ms :timer.seconds(30)

  # Answered at a point rather than near one: there is one answer and it is
  # computed for wherever you are, so "the closest five" means nothing. They
  # all took a foci already; the anchor is simply a different one.
  @asked_at_a_point [:weather, :ephem, :pollen, :icarus]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("plani" <> opts[:id]))
  end

  def init(opts) do
    Configuration.subscribe(:plani, opts[:id])

    Periodic.start_link(
      every: :timer.seconds(60),
      run: fn -> refresh_db_cfg(opts[:id]) end,
      initial_delay: 10
    )

    Periodic.start_link(
      every: @tick_ms,
      run: fn -> query(opts[:id]) end,
      initial_delay: 500
    )

    {:ok,
     %{
       id: opts[:id],
       plani: nil,
       data: %{},
       queries: [],
       places: [],
       notes: %{},
       anchor: nil,
       anchored_to: :home
     }}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def refresh_db_cfg(name), do: "plani#{name}" |> via_tuple() |> GenServer.cast(:refresh_db_cfg)

  def query(name), do: "plani#{name}" |> via_tuple() |> GenServer.cast(:query)

  @doc """
  What this Plani currently has, in the shape a Pythiae publishes.

  Deliberately the same shape the Vision worker returns, so everything
  downstream -- the condensers, Ankyra, every client -- cannot tell which of
  the two it is reading.
  """
  def get_state(name) do
    try do
      "plani#{name}" |> via_tuple() |> GenServer.call(:return_state, 15_000)
    rescue
      ArgumentError -> empty()
    catch
      :exit, _ -> empty()
    end
  end

  # A Plani whose worker is not up yet: it has nothing to say, and saying so
  # is better than a Pythiae crashing on the way out of a deploy.
  defp empty, do: %{data: %{}, queries: []}

  @doc """
  Where this Plani currently thinks it is, and how it knows.

  `:client` means somebody reported inside the window; `:home` means nobody
  has and the home foci is answering. Worth showing on a page, because a Plani
  answering from home looks exactly like a Plani answering from a client that
  happens to be at home.
  """
  def where(name) do
    try do
      "plani#{name}" |> via_tuple() |> GenServer.call(:where, 5_000)
    rescue
      # A registry that is not up raises from the lookup before any call
      # happens, where a dead process would have exited -- a node still
      # booting, or a test. Not knowing where a Plani is is a normal answer.
      ArgumentError -> nil
    catch
      :exit, _ -> nil
    end
  end

  def handle_cast(:refresh_db_cfg, state) do
    {:noreply, %{state | plani: Configuration.get_plani!(state.id)}}
  end

  def handle_cast(:query, %{plani: nil} = state), do: {:noreply, state}

  def handle_cast(:query, state) do
    {anchor, anchored_to} = anchor(state.plani)

    # Resolved on every tick rather than held: a source tinted since the last
    # one should join without the Plani being edited, which is the whole point
    # of following a tint.
    sources =
      RoomSanctum.Configuration.Plani.sources_for(
        state.plani,
        Configuration.list_cfg_sources({:user, state.plani.user_id})
      )

    {data, queries, places, notes} =
      sources
      |> Enum.reduce({%{}, [], [], %{}}, fn source_id, {data, queries, places, notes} ->
        case ask(source_id, anchor, state.plani) do
          nil ->
            {data, queries, places, Map.put(notes, source_id, :not_spatial)}

          {:error, _id, message} ->
            Logger.warning("plani #{state.id} source #{source_id}: #{message}")
            {data, queries, places, Map.put(notes, source_id, {:error, message})}

          {entries, found} ->
            # One source can answer with several entries now: broken out, a
            # stop is an entry of its own.
            data =
              Enum.reduce(entries, data, fn {key, results, _q}, acc ->
                Map.put(acc, key, results)
              end)

            described = Enum.map(entries, fn {_key, _results, q} -> q end)
            counted = entries |> Enum.map(fn {_k, results, _q} -> length(results) end) |> Enum.sum()

            {data, Enum.reverse(described) ++ queries, found ++ places,
             Map.put(notes, source_id, {:ok, counted})}
        end
      end)

    {:noreply,
     %{
       state
       | data: data,
         queries: Enum.reverse(queries),
         places: places,
         notes: notes,
         anchor: anchor,
         anchored_to: anchored_to
     }}
  end

  def handle_call(:where, _from, state) do
    {:reply,
     %{
       anchor: state.anchor,
       anchored_to: state.anchored_to,
       places: state.places,
       notes: state.notes
     }, state}
  end

  def handle_call(:return_state, _from, state) do
    {:reply, %{data: state.data, queries: state.queries}, state}
  end

  def handle_info({:cfg_changed, :plani, _id}, state), do: handle_cast(:refresh_db_cfg, state)

  def handle_info(_msg, state), do: {:noreply, state}

  # Where to ask from: the client if it has said recently, the home foci if not.
  defp anchor(plani) do
    reported =
      if plani.ankyra_id do
        RoomSanctum.Worker.Ankyra.position(to_string(plani.ankyra_id), plani.client_id)
      end

    case reported do
      %{lat: lat, lon: lon} ->
        {%Geo.Point{coordinates: {lon, lat}, srid: 4326}, :client}

      _ ->
        {Configuration.get_foci!(plani.home_foci_id).place, :home}
    end
  end

  # What is near the anchor, for one source. The shape of the answer matches
  # what the equivalent query would have returned, so the condensers need to
  # know nothing about Plani.
  defp ask(source_id, %Geo.Point{} = anchor, plani) do
    source = Configuration.get_source!(:bare, source_id)

    case source.type do
      :gtfs ->
        stops = Storage.nearby_stops(source_id, anchor, plani.limit, plani.radius)

        by_stop =
          Enum.map(stops, fn stop ->
            arrivals =
              source_id
              |> Storage.get_upcoming_arrivals_for_stop(stop.stop_id, 8, :now, source.config.tz)
              |> Storage.fix_arrival_times()
              |> Enum.sort_by(& &1.arrival_time)

            {stop, arrivals}
          end)

        entries =
          if plani.break_out do
            # One entry per stop, named after it, the way a vision's queries
            # are. A stop with nothing due is left out rather than published
            # empty -- the same call the clients already make.
            for {stop, arrivals} <- by_stop, arrivals != [] do
              key = "#{source_id}:#{stop.stop_id}"
              {{key, :gtfs}, arrivals, described(source, key, stop.stop_name)}
            end
          else
            blended =
              by_stop
              |> Enum.flat_map(fn {_stop, arrivals} -> arrivals end)
              |> Enum.sort_by(& &1.arrival_time)
              |> Enum.take(16)

            [{{source_id, :gtfs}, blended, described(source)}]
          end

        {entries, places(stops, source, :stop)}

      :gbfs ->
        # Both, because a source does not say which kind it is. A docked
        # system answers with docks and a dockless one with loose bikes, and
        # asking only for the latter left a city full of docks looking empty.
        bikes = Storage.free_bikes_near(source_id, anchor, plani.radius)
        docks = Storage.stations_near(source_id, anchor, plani.radius)

        entries =
          if plani.break_out do
            # A dock is a place, so it gets its own entry. Loose bikes are not
            # -- they are a count of what is lying about nearby -- so they stay
            # together under the source.
            per_dock =
              for dock <- docks do
                key = "#{source_id}:#{dock.station_id}"
                {{key, :gbfs}, [dock], described(source, key, dock.name)}
              end

            if bikes == [],
              do: per_dock,
              else: [{{source_id, :gbfs}, bikes, described(source)} | per_dock]
          else
            [{{source_id, :gbfs}, bikes ++ docks, described(source)}]
          end

        {entries, places(bikes, source, :bike) ++ places(docks, source, :dock)}

      :aqi ->
        readings = Storage.nearby_aqi_stations(source_id, anchor, plani.limit)
        {[{{source_id, :aqi}, readings, described(source)}], places(readings, source, :monitor)}

      type when type in @asked_at_a_point ->
        # Answered *at* the anchor rather than near it. These name a foci in a
        # vision -- the weather at home, sunrise at home -- and the only thing
        # a Plani changes is where "at" is. The query is the anchor itself,
        # which `Configuration.place_for!/1` prefers over a foci id.
        results = ask_at(type, source_id, %{place: anchor})
        {[{{source_id, type}, results, described(source)}], []}

      other ->
        # Sources with nothing located in them. Left out rather than guessed
        # at; the page says what it could not draw.
        Logger.debug("plani: no spatial answer for a #{other} source")
        nil
    end
  rescue
    # `catch` takes throws and exits and lets a raise straight through, so one
    # source with no config, or a stop id that has gone, took the whole worker
    # down on every tick -- it restarted, lost its state, and the page stayed
    # empty with nothing anywhere saying why.
    error ->
      {:error, source_id, Exception.message(error)}
  catch
    kind, reason ->
      {:error, source_id, "#{kind}: #{inspect(reason)}"}
  end

  defp ask(_source_id, _anchor, _plani), do: nil

  # What the condensers expect alongside the data: a vision hands them a query,
  # so a Plani hands them something query-shaped. The empty `query` matters --
  # the GTFS condenser reads a stop out of it to look up stop-specific alerts,
  # and a Plani has no one stop any more than an area query does.
  # What the condensers expect alongside the data: a vision hands them a query,
  # so a Plani hands them something query-shaped. The id has to match the key
  # the data went under -- that is how the two are paired again -- so a broken
  # out entry carries its own, or its name is dropped on the way out.
  defp described(source), do: described(source, source.id, source.name)

  defp described(source, id, name) do
    %{id: id, name: name, meta: %{}, query: %{}}
  end

  # Asked at the anchor. Each of these already takes a query naming a foci; a
  # Plani hands over a place instead and they resolve it the same way.
  defp ask_at(:weather, source_id, query), do: RoomWeather.Worker.query_weather(source_id, query)
  defp ask_at(:ephem, source_id, query), do: RoomEphem.Worker.query_ephem(source_id, query)
  # These two read from a worker that may not be up, exactly as the vision
  # worker calls them.
  defp ask_at(:pollen, source_id, query) do
    if RoomPollen.Worker.pid(source_id),
      do: RoomPollen.Worker.read(source_id, query) || [],
      else: []
  end

  defp ask_at(:icarus, source_id, query) do
    if RoomIcarus.Worker.pid(source_id),
      do: RoomIcarus.Worker.read(source_id, query) || [],
      else: []
  end

  # Where the things it found actually are, for anything drawing a map.
  #
  # Flattened to one shape rather than kept as the records they came from: a
  # stop, a loose bike and an air quality monitor are three different rows in
  # three different tables, and all a map wants of any of them is a point, a
  # name and which of the three it is.
  defp places(records, source, kind) do
    records
    |> Enum.map(fn record ->
      case coordinates(record) do
        nil ->
          nil

        {lat, lon} ->
          %{
            lat: lat,
            lon: lon,
            kind: kind,
            name: name_of(record, kind),
            source_id: source.id,
            source_name: source.name,
            tint: source.meta && Map.get(source.meta, :tint)
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Each table spells its position differently: stops carry the floats they
  # were imported with, the rest carry a point.
  defp coordinates(%{stop_lat: lat, stop_lon: lon}) when is_number(lat) and is_number(lon),
    do: {lat, lon}

  defp coordinates(%{lat: lat, lon: lon}) when is_number(lat) and is_number(lon), do: {lat, lon}

  defp coordinates(%{point: %Geo.Point{coordinates: {lon, lat}}}), do: {lat, lon}

  defp coordinates(%{place: %Geo.Point{coordinates: {lon, lat}}}), do: {lat, lon}

  defp coordinates(_record), do: nil

  defp name_of(%{stop_name: name}, :stop) when is_binary(name), do: name
  defp name_of(%{name: name}, _kind) when is_binary(name), do: name
  defp name_of(%{site_name: name}, :monitor) when is_binary(name), do: name
  defp name_of(%{bike_id: id}, :bike), do: id
  defp name_of(_record, kind), do: to_string(kind)
end
