defmodule RoomTreasury.Worker do
  @moduledoc """
  Currency, crypto and metal prices from fawazahmed0's exchange-api.

  No key and no rate limits, but the data only moves once a day, so rates are
  cached per base currency and refreshed hourly rather than per read.

  The upstream README asks consumers to fall back to a second host if the CDN
  fails, so `fetch_base/2` tries jsDelivr and then the Cloudflare Pages mirror
  before giving up.

  A quote is one fetch per *base* currency, not per pair: asking for usd/eur,
  usd/gbp and usd/jpy is a single request whose rates are read three ways.
  """
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus

  # The upstream README asks consumers to try a second host if the CDN fails.
  # Overridable so the failover path can actually be exercised -- a fallback you
  # have never run is a fallback you find out about during an outage.
  @primary_default "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{date}/v1"
  @fallback_default "https://{date}.currency-api.pages.dev/v1"

  def primary_template,
    do: Application.get_env(:room_treasury, :primary_base, @primary_default)

  def fallback_template,
    do: Application.get_env(:room_treasury, :fallback_base, @fallback_default)

  @doc "The URLs `fetch/2` will try, in order."
  def urls_for(path, date \\ "latest") do
    [primary_template(), fallback_template()]
    |> Enum.map(&(String.replace(&1, "{date}", date) <> "/" <> path))
  end

  # Rates are published daily; hourly keeps a long-running node current without
  # hammering a free service.
  @refresh_seconds 3600

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("treasury#{opts[:name]}"))
  end

  def init(opts) do
    Periodic.start_link(
      # A backstop rather than a poll: source config changes are rare, and the
      # workers that read them on a tight timer were the load that kept a
      # ten-connection pool saturated. Nothing here needs to notice an edit
      # within ten seconds.
      every: :timer.seconds(60),
      run: fn -> RoomTreasury.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(@refresh_seconds),
      run: fn -> RoomTreasury.Worker.refresh_rates(opts[:name]) end,
      initial_delay: :timer.seconds(5)
    )

    {:ok, %{id: opts[:name], inst: %{}, rates: %{}, names: %{}}}
  end

  def pid(name), do: "treasury#{name}" |> via_tuple() |> GenServer.whereis()

  def refresh_db_cfg(name), do: GenServer.cast(via_tuple("treasury#{name}"), :refresh_db_cfg)
  def refresh_rates(name), do: GenServer.cast(via_tuple("treasury#{name}"), :refresh_rates)
  def read(name, query), do: GenServer.call(via_tuple("treasury#{name}"), {:read, query}, 30_000)

  def handle_cast(:refresh_db_cfg, state) do
    {:noreply, Map.put(state, :inst, Configuration.get_source!(state.id))}
  end

  # Only bases already asked for are refreshed -- there is no point pulling all
  # 300-odd currencies for a query that wants two of them.
  def handle_cast(:refresh_rates, %{inst: %{enabled: true}} = state) do
    rates =
      state.rates
      |> Map.keys()
      |> Enum.reduce(state.rates, fn base, acc ->
        case fetch_base(base) do
          {:ok, payload} -> Map.put(acc, base, payload)
          :error -> acc
        end
      end)

    {:noreply, %{state | rates: rates}}
  end

  def handle_cast(:refresh_rates, state), do: {:noreply, state}

  def handle_call({:read, query}, _from, state) do
    from = normalise(field(query, :from))
    to = normalise(field(query, :to))
    precision = field(query, :precision) || 4

    cond do
      is_nil(from) or is_nil(to) ->
        {:reply, [], state}

      true ->
        {rates, state} =
          case Map.get(state.rates, from) do
            nil ->
              case fetch_base(from) do
                {:ok, payload} -> {Map.put(state.rates, from, payload), state}
                :error -> {state.rates, state}
              end

            _ ->
              {state.rates, state}
          end

        state = %{state | rates: rates, names: names(state)}
        {:reply, [quote_pair({from, to}, state, precision)], state}
    end
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  defp quote_pair({from, to}, state, precision) do
    case get_in(state.rates, [from, "rates", to]) do
      nil ->
        %{
          pair: "#{String.upcase(from)}/#{String.upcase(to)}",
          from: from,
          to: to,
          rate: nil,
          error: "no rate available"
        }

      rate when is_number(rate) ->
        %{
          pair: "#{String.upcase(from)}/#{String.upcase(to)}",
          from: from,
          to: to,
          from_name: state.names[from] || String.upcase(from),
          to_name: state.names[to] || String.upcase(to),
          rate: rate,
          # Crypto rates run to eight significant figures, so a fixed decimal
          # count would show 0.0000 for anything priced against BTC.
          display: format_rate(rate, precision),
          date: get_in(state.rates, [from, "date"])
        }

      _ ->
        nil
    end
  end

  @doc "Round for display, keeping small rates legible rather than all zeroes."
  def format_rate(rate, precision) when is_number(rate) do
    cond do
      rate == 0 -> "0"
      abs(rate) >= 1 -> :erlang.float_to_binary(rate / 1, decimals: precision)
      true -> significant(rate / 1, max(precision, 4))
    end
  end

  def format_rate(_, _), do: "—"

  # For sub-1 values keep `sig` significant digits rather than `sig` decimals.
  defp significant(value, sig) do
    magnitude = :math.log10(abs(value)) |> Float.floor() |> trunc()
    decimals = min(max(sig - 1 - magnitude, 0), 15)
    :erlang.float_to_binary(value, decimals: decimals)
  end

  defp names(%{names: names}) when map_size(names) > 0, do: names

  defp names(_state) do
    case fetch("currencies.min.json") do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  @doc """
  Rates for one base currency, normalised to `%{"date" => ..., "rates" => %{}}`.

  Upstream keys the rate map by the base currency itself, which would otherwise
  make every read have to know what it asked for.
  """
  def fetch_base(base, date \\ "latest") do
    case fetch("currencies/#{base}.min.json", date) do
      {:ok, payload} when is_map(payload) ->
        case Map.get(payload, base) do
          rates when is_map(rates) -> {:ok, %{"date" => payload["date"], "rates" => rates}}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp fetch(path, date \\ "latest") do
    # Falls through on a connection error *and* on any non-200, since a CDN
    # serving a 5xx is just as useless as one that will not answer.
    path
    |> urls_for(date)
    |> Enum.reduce_while(:error, fn url, _acc ->
      case HTTPoison.get(url, [{"Accept", "application/json"}],
             recv_timeout: 15_000,
             follow_redirect: true
           ) do
        {:ok, %{status_code: 200, body: body}} ->
          case Poison.decode(body) do
            {:ok, decoded} -> {:halt, {:ok, decoded}}
            {:error, _} -> {:cont, :error}
          end

        {:ok, %{status_code: code}} ->
          Logger.debug("Treasury #{url} -> HTTP #{code}")
          {:cont, :error}

        {:error, err} ->
          Logger.debug("Treasury #{url} -> #{inspect(err.reason)}")
          {:cont, :error}
      end
    end)
    |> case do
      {:ok, decoded} ->
        {:ok, decoded}

      :error ->
        Logger.warning("Treasury: both hosts failed for #{path}")
        :error
    end
  end

  defp field(query, key), do: Map.get(query, key) || Map.get(query, Atom.to_string(key))

  defp normalise(code) when is_binary(code) do
    case code |> String.trim() |> String.downcase() do
      "" -> nil
      value -> value
    end
  end

  defp normalise(_), do: nil

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
