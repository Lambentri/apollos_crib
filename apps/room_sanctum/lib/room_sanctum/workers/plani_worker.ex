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

    {:ok, %{id: opts[:id], plani: nil, data: %{}, queries: [], anchor: nil, anchored_to: :home}}
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

    {data, queries} =
      sources
      |> Enum.reduce({%{}, []}, fn source_id, {data, queries} ->
        case ask(source_id, anchor, state.plani) do
          nil ->
            {data, queries}

          {key, results, described} ->
            {Map.put(data, key, results), [described | queries]}
        end
      end)

    {:noreply, %{state | data: data, queries: Enum.reverse(queries), anchor: anchor, anchored_to: anchored_to}}
  end

  def handle_call(:where, _from, state) do
    {:reply, %{anchor: state.anchor, anchored_to: state.anchored_to}, state}
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
        stops = Storage.nearby_stops(source_id, anchor, plani.limit) |> Enum.map(& &1.stop_id)

        arrivals =
          stops
          |> Enum.flat_map(&Storage.get_upcoming_arrivals_for_stop(source_id, &1, 8, :now, source.config.tz))
          |> Storage.fix_arrival_times()
          |> Enum.sort_by(& &1.arrival_time)
          |> Enum.take(16)

        {{source_id, :gtfs}, arrivals, described(source)}

      :gbfs ->
        bikes = Storage.free_bikes_near(source_id, anchor, plani.radius)
        {{source_id, :gbfs}, bikes, described(source)}

      :aqi ->
        readings = Storage.nearby_aqi_stations(source_id, anchor, plani.limit)
        {{source_id, :aqi}, readings, described(source)}

      other ->
        # Sources with nothing located in them, or nothing near-able yet. Left
        # out rather than guessed at; the board says what it could not draw.
        Logger.debug("plani: no spatial answer for a #{other} source")
        nil
    end
  catch
    kind, reason ->
      Logger.warning("plani source #{source_id} #{kind}: #{inspect(reason)}")
      nil
  end

  defp ask(_source_id, _anchor, _plani), do: nil

  # What the condensers expect alongside the data: a vision hands them a query,
  # so a Plani hands them something query-shaped. The empty `query` matters --
  # the GTFS condenser reads a stop out of it to look up stop-specific alerts,
  # and a Plani has no one stop any more than an area query does.
  defp described(source) do
    %{id: source.id, name: source.name, meta: %{}, query: %{}}
  end
end
