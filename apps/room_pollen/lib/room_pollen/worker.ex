defmodule RoomPollen.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @config_module RoomSanctum.Configuration.Configs.Pollen
  @endpoint "https://pollen.googleapis.com/v1/forecast:lookup"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("pollen#{opts[:name]}"))
  end

  def init(opts) do
    Periodic.start_link(
      # A backstop rather than a poll: source config changes are rare, and the
      # workers that read them on a tight timer were the load that kept a
      # ten-connection pool saturated. Nothing here needs to notice an edit
      # within ten seconds.
      every: :timer.seconds(60),
      run: fn -> RoomPollen.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(60 * 60 * 6),
      run: fn -> RoomPollen.Worker.refresh_forecasts(opts[:name]) end,
      initial_delay: :timer.seconds(15)
    )

    {:ok,
     %{
       id: opts[:name],
       inst: %{},
       targets: MapSet.new(),
       forecasts: %{}
     }}
  end

  def pid(name) do
    "pollen#{name}"
    |> via_tuple()
    |> GenServer.whereis()
  end

  # Public API
  def refresh_db_cfg(name), do: GenServer.cast(via("pollen#{name}"), :refresh_db_cfg)
  def refresh_forecasts(name), do: GenServer.cast(via("pollen#{name}"), :refresh_forecasts)
  def read(name, query), do: GenServer.call(via("pollen#{name}"), {:read, query})

  # Cast handlers
  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:refresh_forecasts, state) do
    case creds(state.inst) do
      {:ok, key} ->
        Logger.info(
          "Pollen::#{state.inst.id} refreshing #{MapSet.size(state.targets)} targets"
        )

        new_forecasts =
          state.targets
          |> Enum.reduce(state.forecasts, fn {lat, lng, days}, acc ->
            case fetch_forecast(key, lat, lng, days) do
              {:ok, daily_info} -> Map.put(acc, {lat, lng, days}, daily_info)
              :error -> acc
            end
          end)

        {:noreply, state |> Map.put(:forecasts, new_forecasts)}

      :no_creds ->
        {:noreply, state}
    end
  end

  def handle_cast({:add_target, target}, state) do
    {:noreply, state |> Map.put(:targets, MapSet.put(state.targets, target))}
  end

  # Call handlers
  def handle_call({:read, query}, _from, state) do
    target = target_from_query(query)

    result =
      case target do
        nil ->
          []

        {lat, lng, days} ->
          GenServer.cast(self(), {:add_target, {lat, lng, days}})

          case Map.get(state.forecasts, {lat, lng, days}) do
            nil ->
              # Lazy fetch on first read
              case creds(state.inst) do
                {:ok, key} ->
                  case fetch_forecast(key, lat, lng, days) do
                    {:ok, daily_info} -> daily_info
                    :error -> []
                  end

                :no_creds ->
                  []
              end

            cached ->
              cached
          end
      end

    {:reply, result, state}
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  # Helpers
  defp via(name), do: via_tuple(name)
  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  defp creds(%{enabled: true, config: %{__struct__: @config_module, api_key: key}})
       when is_binary(key) and key != "",
       do: {:ok, key}

  defp creds(_), do: :no_creds

  defp target_from_query(query) do
    # A place if one was handed over, otherwise the foci named in the query.
    anchor =
      RoomSanctum.Configuration.place_for!(query) ||
        Map.get(query, :foci_id) || Map.get(query, "foci_id")

    days =
      case Map.get(query, :days) || Map.get(query, "days") do
        n when is_integer(n) and n in 1..5 -> n
        n when is_binary(n) -> String.to_integer(n) |> max(1) |> min(5)
        _ -> 3
      end

    case resolve_foci(anchor) do
      {lat, lng} -> {lat, lng, days}
      nil -> nil
    end
  end

  defp resolve_foci(nil), do: nil

  # A Plani asks from wherever its client is, which is not a foci and has no
  # row to look up.
  # Matched by shape rather than as a %Geo.Point{}: this app does not
  # depend on geo, and the only thing here with coordinates is a place.
  defp resolve_foci(%{coordinates: {lng, lat}}), do: {lat, lng}

  defp resolve_foci(foci_id) do
    try do
      case Configuration.get_foci!(foci_id) do
        %{place: %{coordinates: {lng, lat}}} -> {lat, lng}
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp fetch_forecast(key, lat, lng, days) do
    url =
      "#{@endpoint}?key=#{URI.encode(key)}" <>
        "&location.latitude=#{lat}&location.longitude=#{lng}" <>
        "&days=#{days}&plantsDescription=true"

    case HTTPoison.get(url, [{"Accept", "application/json"}], recv_timeout: 15_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, %{"dailyInfo" => daily}} when is_list(daily) ->
            {:ok, daily}

          {:ok, _} ->
            Logger.warning("Pollen unexpected response shape")
            :error

          {:error, _} ->
            Logger.warning("Pollen JSON decode failed")
            :error
        end

      {:ok, %{status_code: code, body: body}} ->
        Logger.warning("Pollen HTTP #{code}: #{String.slice(body, 0, 200)}")
        :error

      {:error, err} ->
        Logger.warning("Pollen HTTP error: #{inspect(err.reason)}")
        :error
    end
  end
end
