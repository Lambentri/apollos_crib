defmodule RoomDrought.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @drought_config_module RoomSanctum.Configuration.Configs.Drought
  @usdm_base "https://usdmdataservices.unl.edu/api"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("drought#{opts[:name]}"))
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomDrought.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(60 * 60 * 6),
      run: fn -> RoomDrought.Worker.refresh_usdm(opts[:name]) end,
      initial_delay: :timer.seconds(15)
    )

    {:ok,
     %{
       id: opts[:name],
       inst: %{},
       usdm: %{},
       targets: MapSet.new()
     }}
  end

  def pid(name) do
    "drought#{name}"
    |> via_tuple()
    |> GenServer.whereis()
  end

  # Public API
  def refresh_db_cfg(name), do: GenServer.cast(via("drought#{name}"), :refresh_db_cfg)
  def refresh_usdm(name), do: GenServer.cast(via("drought#{name}"), :refresh_usdm)
  def add_target(name, scope), do: GenServer.cast(via("drought#{name}"), {:add_target, scope})
  def read(name, query), do: GenServer.call(via("drought#{name}"), {:read, query})

  # Cast handlers
  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    {:noreply, state |> Map.put(:inst, inst)}
  end

  def handle_cast(:refresh_usdm, state) do
    if usdm_enabled?(state.inst) do
      Logger.info("Drought::#{state.inst.id} refreshing USDM (#{MapSet.size(state.targets)} targets)")

      new_usdm =
        state.targets
        |> Enum.reduce(state.usdm, fn target, acc ->
          case fetch_usdm(target) do
            {:ok, record} -> Map.put(acc, target, record)
            :error -> acc
          end
        end)

      {:noreply, state |> Map.put(:usdm, new_usdm)}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:add_target, scope}, state) do
    target = normalize_scope(scope)

    if target do
      {:noreply, state |> Map.put(:targets, MapSet.put(state.targets, target))}
    else
      {:noreply, state}
    end
  end

  # Call handlers
  def handle_call({:read, query}, _from, state) do
    product = Map.get(query, :product) || Map.get(query, "product") || "usdm"

    result =
      case product do
        "usdm" ->
          case scope_from_query(query) do
            nil ->
              []

            target ->
              # Make sure we're tracking it for next refresh
              GenServer.cast(self(), {:add_target, target})

              case Map.get(state.usdm, target) do
                nil ->
                  case fetch_usdm(target) do
                    {:ok, record} -> [record]
                    :error -> []
                  end

                record ->
                  [record]
              end
          end

        product when product in ["csi", "cpc", "gpcc"] ->
          [%{"product" => product, "status" => "not_yet_implemented"}]

        _ ->
          []
      end

    {:reply, result, state}
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  # Helpers
  defp via(name), do: via_tuple(name)
  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  defp usdm_enabled?(%{enabled: true, config: %{__struct__: @drought_config_module, products: products}})
       when is_list(products),
       do: "usdm" in products

  defp usdm_enabled?(_), do: false

  defp scope_from_query(query) do
    fips = Map.get(query, :fips) || Map.get(query, "fips")
    state = Map.get(query, :state) || Map.get(query, "state")

    cond do
      is_binary(fips) and fips != "" -> {:county, fips}
      is_binary(state) and state != "" -> {:state, String.upcase(state)}
      true -> nil
    end
  end

  defp normalize_scope({:county, fips}) when is_binary(fips), do: {:county, fips}
  defp normalize_scope({:state, st}) when is_binary(st), do: {:state, String.upcase(st)}
  defp normalize_scope(_), do: nil

  defp fetch_usdm({:county, fips}) do
    fetch_usdm_path("/CountyStatistics/GetDroughtSeverityStatisticsByAreaPercent", fips)
  end

  defp fetch_usdm({:state, st}) do
    fetch_usdm_path("/StateStatistics/GetDroughtSeverityStatisticsByAreaPercent", st)
  end

  defp fetch_usdm_path(path, aoi) do
    today = Date.utc_today()
    start_date = today |> Date.add(-60) |> format_usdm_date()
    end_date = today |> format_usdm_date()

    url =
      "#{@usdm_base}#{path}?aoi=#{URI.encode(aoi)}" <>
        "&startdate=#{start_date}&enddate=#{end_date}&statisticsType=1"

    case HTTPoison.get(url, [{"Accept", "application/json"}], recv_timeout: 15_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, [_ | _] = list} ->
            # API returns most-recent first
            {:ok, List.first(list)}

          {:ok, []} ->
            Logger.info("USDM empty list for #{aoi}")
            :error

          {:error, _} ->
            Logger.warning("USDM JSON decode failed for #{aoi}")
            :error
        end

      {:ok, %{status_code: code}} ->
        Logger.warning("USDM HTTP #{code} for #{aoi}")
        :error

      {:error, err} ->
        Logger.warning("USDM HTTP error for #{aoi}: #{inspect(err.reason)}")
        :error
    end
  end

  defp format_usdm_date(%Date{year: y, month: m, day: d}), do: "#{m}/#{d}/#{y}"
end
