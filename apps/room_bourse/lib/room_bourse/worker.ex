defmodule RoomBourse.Worker do
  @moduledoc """
  Quotes from Yahoo Finance's chart endpoint.

  This is the same endpoint the Python `yfinance` library calls; talking to it
  directly avoids embedding a CPython runtime (`pythonx`) and a Rust dataframe
  NIF (`explorer`) in the release for what is one JSON GET.

  Everything the quote needs lives in the response's `meta` object, so requests
  ask for the shortest possible series (`range=1d&interval=1d`) -- about 1.6 KB
  rather than a full history.

  Unofficial and unauthenticated: Yahoo publishes no API and can change or
  throttle this at will. That is the same exposure `yfinance` itself carries.
  """
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @endpoint_default "https://query1.finance.yahoo.com"

  # Quotes move constantly, but a dashboard does not need tick-level data and
  # Yahoo throttles enthusiastic clients.
  @refresh_seconds 300
  # Spacing between symbols on a sweep, for the same reason.
  @request_spacing_ms 400

  def endpoint, do: Application.get_env(:room_bourse, :endpoint, @endpoint_default)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("bourse#{opts[:name]}"))
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomBourse.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(@refresh_seconds),
      run: fn -> RoomBourse.Worker.refresh_quotes(opts[:name]) end,
      initial_delay: :timer.seconds(5)
    )

    {:ok, %{id: opts[:name], inst: %{}, quotes: %{}}}
  end

  def pid(name), do: "bourse#{name}" |> via_tuple() |> GenServer.whereis()

  def refresh_db_cfg(name), do: GenServer.cast(via_tuple("bourse#{name}"), :refresh_db_cfg)
  def refresh_quotes(name), do: GenServer.cast(via_tuple("bourse#{name}"), :refresh_quotes)
  def read(name, query), do: GenServer.call(via_tuple("bourse#{name}"), {:read, query}, 30_000)

  def handle_cast(:refresh_db_cfg, state) do
    {:noreply, Map.put(state, :inst, Configuration.get_source!(state.id))}
  end

  # Only symbols something has actually asked for get refreshed.
  def handle_cast(:refresh_quotes, %{inst: %{enabled: true}} = state) do
    quotes =
      state.quotes
      |> Map.keys()
      |> Enum.reduce(state.quotes, fn symbol, acc ->
        result = quote_for(symbol)
        Process.sleep(@request_spacing_ms)

        case result do
          {:ok, q} -> Map.put(acc, symbol, q)
          {:error, _} -> acc
        end
      end)

    {:noreply, %{state | quotes: quotes}}
  end

  def handle_cast(:refresh_quotes, state), do: {:noreply, state}

  def handle_call({:read, query}, _from, state) do
    case normalise(field(query, :symbol)) do
      nil ->
        {:reply, [], state}

      symbol ->
        {result, state} =
          case Map.get(state.quotes, symbol) do
            nil ->
              case quote_for(symbol) do
                {:ok, q} -> {q, %{state | quotes: Map.put(state.quotes, symbol, q)}}
                {:error, reason} -> {%{symbol: String.upcase(symbol), error: reason}, state}
              end

            cached ->
              {cached, state}
          end

        {:reply, [result], state}
    end
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  @doc """
  A single quote, or `{:error, message}` with something worth showing a user.
  """
  def quote_for(symbol) do
    url = "#{endpoint()}/v8/finance/chart/#{URI.encode(symbol, &URI.char_unreserved?/1)}?range=1d&interval=1d"

    # Yahoo returns 404 for unknown symbols with a usable description, so a
    # non-200 body is still worth decoding before giving up on it.
    case HTTPoison.get(url, [{"Accept", "application/json"}, {"User-Agent", user_agent()}],
           recv_timeout: 15_000,
           follow_redirect: true
         ) do
      {:ok, %{status_code: 200, body: body}} ->
        decode(body, symbol)

      {:ok, %{status_code: code, body: body}} ->
        case describe_error(body) do
          nil -> {:error, "Yahoo returned HTTP #{code}"}
          message -> {:error, message}
        end

      {:error, err} ->
        Logger.debug("Bourse #{symbol}: #{inspect(err.reason)}")
        {:error, "could not reach Yahoo Finance"}
    end
  end

  defp decode(body, symbol) do
    case Poison.decode(body) do
      {:ok, %{"chart" => %{"result" => [%{"meta" => meta} | _]}}} ->
        {:ok, present(meta, symbol)}

      {:ok, %{"chart" => %{"error" => %{"description" => description}}}} ->
        {:error, description}

      _ ->
        {:error, "unexpected response for #{String.upcase(symbol)}"}
    end
  end

  defp describe_error(body) do
    case Poison.decode(body) do
      {:ok, %{"chart" => %{"error" => %{"description" => description}}}} -> description
      _ -> nil
    end
  end

  defp present(meta, symbol) do
    price = meta["regularMarketPrice"]
    previous = meta["chartPreviousClose"] || meta["previousClose"]
    change = if is_number(price) and is_number(previous), do: price - previous
    change_pct = if is_number(change) and is_number(previous) and previous != 0, do: change / previous * 100

    %{
      symbol: meta["symbol"] || String.upcase(symbol),
      # Indices and crypto often carry only a short name.
      name: meta["longName"] || meta["shortName"],
      exchange: meta["fullExchangeName"] || meta["exchangeName"],
      # Some London listings quote in pence (GBp), not pounds -- worth showing
      # verbatim rather than assuming the major unit.
      currency: meta["currency"],
      instrument: meta["instrumentType"],
      price: price,
      previous_close: previous,
      change: change,
      change_pct: change_pct,
      direction: direction(change),
      market_time: meta["regularMarketTime"],
      checked_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp direction(change) when is_number(change) and change > 0, do: :up
  defp direction(change) when is_number(change) and change < 0, do: :down
  defp direction(change) when is_number(change), do: :flat
  defp direction(_), do: nil

  @doc "Round a price for display without losing sub-penny instruments."
  def format_price(value) when is_number(value) do
    cond do
      abs(value) >= 1 -> :erlang.float_to_binary(value / 1, decimals: 2)
      value == 0 -> "0"
      true -> :erlang.float_to_binary(value / 1, decimals: 6)
    end
  end

  def format_price(_), do: "—"

  @doc "Signed change, e.g. `+1.41` / `-5.00`."
  def format_change(value) when is_number(value) do
    sign = if value > 0, do: "+", else: ""
    sign <> format_price(value)
  end

  def format_change(_), do: "—"

  @doc "Signed percentage to two places."
  def format_pct(value) when is_number(value) do
    sign = if value > 0, do: "+", else: ""
    sign <> :erlang.float_to_binary(value / 1, decimals: 2) <> "%"
  end

  def format_pct(_), do: ""

  # Yahoo rejects requests without a browser-ish agent.
  defp user_agent,
    do: Application.get_env(:room_bourse, :user_agent, "Mozilla/5.0 (compatible; ApollosCrib/1.0)")

  defp normalise(symbol) when is_binary(symbol) do
    case symbol |> String.trim() |> String.upcase() do
      "" -> nil
      value -> value
    end
  end

  defp normalise(_), do: nil

  defp field(query, key), do: Map.get(query, key) || Map.get(query, Atom.to_string(key))

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
