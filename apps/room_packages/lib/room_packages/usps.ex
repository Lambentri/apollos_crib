defmodule RoomPackages.USPS do
  @moduledoc """
  USPS Tracking (v3) client.

  Unlike UPS, USPS offers no subscription or webhook: the only way to learn that
  a parcel moved is to ask. So numbers are stored on the source and polled by
  `RoomPackages.Worker`, rather than registered once and pushed back to us.

  ## Access

  The `tracking` scope is **not** granted to a USPS developer app automatically.
  An app can hold valid credentials, mint a token successfully, and still get
  401 on every tracking call because the scope came back empty. That has to be
  requested from USPS separately.

  ## Endpoints

      POST https://apis.usps.com/oauth2/v3/token
      POST https://apis.usps.com/tracking/v3r2/tracking
      POST https://apis.usps.com/subscriptions-tracking/v3r2/subscriptions

  Tracking in v3r2 is a POST taking an *array* of up to 35 items, not the
  `GET /tracking/v3/tracking/{number}` of the older v3 API -- that path is what
  the gateway rejects with `OASValidation`. The body is validated strictly
  (`additionalProperties: false`), so nothing extra can be sent along.

  Subscriptions are the better path where the listener is publicly reachable --
  USPS pushes events instead of us asking. Note the scopes differ:
  `tracking` for lookups, `subscriptions-tracking` for subscriptions.

  Hosts are overridable so the USPS test environment can be used:

      config :room_packages, usps_subscriptions_base: "https://apis-tem.usps.com"
  """

  require Logger

  alias RoomSanctum.Configuration

  @oauth_default "https://apis.usps.com"
  @tracking_default "https://apis.usps.com"
  # Refresh a little early rather than racing the expiry on a slow request.
  @expiry_skew_seconds 60

  def oauth_base, do: Application.get_env(:room_packages, :usps_oauth_base, @oauth_default)

  def tracking_base,
    do: Application.get_env(:room_packages, :usps_tracking_base, @tracking_default)

  # The API accepts up to 35 numbers per call, so polling a dozen parcels is one
  # request rather than a dozen.
  @max_batch 35

  def max_batch, do: @max_batch

  @doc "True when the source carries USPS API credentials."
  def configured?(%{config: %{apikey_usps_id: id, apikey_usps_secret: secret}})
      when is_binary(id) and id != "" and is_binary(secret) and secret != "",
      do: true

  def configured?(_), do: false

  @doc """
  A usable bearer token, minting a new one only when the cached one has expired.

  The token is persisted onto the source config the same way the UPS one is, so
  a restart does not force a fresh mint.
  """
  def token(source) do
    cond do
      not configured?(source) ->
        {:error, :not_configured}

      token_valid?(source) ->
        {:ok, source.config.token_usps}

      true ->
        mint_token(source)
    end
  end

  defp token_valid?(%{config: %{token_usps: token, token_usps_expiry: expiry}})
       when is_binary(token) and token != "" and is_binary(expiry) do
    case DateTime.from_iso8601(expiry) do
      {:ok, at, _} -> DateTime.compare(at, DateTime.utc_now()) == :gt
      _ -> false
    end
  end

  defp token_valid?(_), do: false

  defp mint_token(source) do
    conf = source.config

    body =
      Poison.encode!(%{
        client_id: conf.apikey_usps_id,
        client_secret: conf.apikey_usps_secret,
        grant_type: "client_credentials"
      })

    case HTTPoison.post("#{oauth_base()}/oauth2/v3/token", body,
           [{"Content-Type", "application/json"}],
           recv_timeout: 15_000
         ) do
      {:ok, %{status_code: 200, body: raw}} ->
        decoded = Poison.decode!(raw)
        token = decoded["access_token"]
        expires_in = decoded["expires_in"] |> to_int(3600)

        # An app without tracking approval still mints a token happily -- the
        # empty scope is the only warning before every call 401s.
        if decoded["scope"] in [nil, ""] do
          Logger.warning("USPS token has empty scope; the tracking scope may not be approved")
        end

        expiry =
          DateTime.utc_now()
          |> DateTime.add(max(expires_in - @expiry_skew_seconds, 0))
          |> DateTime.to_iso8601()

        Configuration.update_source_config(source, %{token_usps: token, token_usps_expiry: expiry})

        {:ok, token}

      {:ok, %{status_code: code, body: raw}} ->
        Logger.warning("USPS token HTTP #{code}: #{String.slice(raw, 0, 200)}")
        {:error, {:http, code}}

      {:error, err} ->
        Logger.warning("USPS token error: #{inspect(err.reason)}")
        {:error, err.reason}
    end
  end

  @doc """
  Current status for one tracking number.

  Returns `{:ok, summary}` where summary carries a few normalised fields plus the
  raw decoded payload. The normalised keys are read defensively across the
  spellings USPS uses, and `raw` is kept so nothing is lost if the shape differs
  from what the docs describe.
  """
  def track(source, number) do
    case track_many(source, [number]) do
      {:ok, [only]} -> {:ok, only}
      {:ok, []} -> {:error, :not_found}
      {:ok, many} -> {:ok, hd(many)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Status for up to #{@max_batch} numbers in one request.

  Returns `{:ok, summaries}`. A 207 is a partial success -- some numbers
  resolved, others did not -- and is treated the same as a 200, since the
  entries that came back are still worth recording.
  """
  def track_many(_source, []), do: {:ok, []}

  def track_many(source, numbers) when length(numbers) > @max_batch do
    {:error, {:too_many, length(numbers)}}
  end

  def track_many(source, numbers) do
    with {:ok, token} <- token(source) do
      # additionalProperties: false -- only trackingNumber may be sent here.
      body = Poison.encode!(Enum.map(numbers, &%{trackingNumber: &1}))
      url = "#{tracking_base()}/tracking/v3r2/tracking"

      case HTTPoison.post(url, body,
             [
               {"Authorization", "Bearer #{token}"},
               {"Content-Type", "application/json"},
               {"Accept", "application/json"}
             ],
             recv_timeout: 30_000
           ) do
        {:ok, %{status_code: code, body: raw}} when code in [200, 207] ->
          {:ok, raw |> Poison.decode!() |> List.wrap() |> Enum.map(&summarise(&1, &1["trackingNumber"]))}

        {:ok, %{status_code: 400, body: raw}} ->
          Logger.warning("USPS tracking rejected the request: #{String.slice(raw, 0, 300)}")
          {:error, :bad_request}

        {:ok, %{status_code: 401, body: raw}} ->
          Logger.warning("USPS 401 -- is the tracking scope approved? #{String.slice(raw, 0, 200)}")
          {:error, :unauthorized}

        {:ok, %{status_code: 404}} ->
          {:error, :not_found}

        {:ok, %{status_code: code, body: raw}} ->
          Logger.warning("USPS tracking HTTP #{code}: #{String.slice(raw, 0, 200)}")
          {:error, {:http, code}}

        {:error, err} ->
          {:error, err.reason}
      end
    end
  end

  # USPS spells these differently across versions and examples, so each field is
  # tried across its plausible names rather than assuming one.
  @doc false
  def __summarise_for_test__(payload, number), do: summarise(payload, number)

  defp summarise(payload, number) do
    %{
      number: number,
      status: first_of(payload, ["status", "statusSummary", "statusCategory"]),
      delivered: delivered?(payload),
      expected: first_of(payload, ["expectedDeliveryDate", "predictedDeliveryDate", "guaranteedDeliveryDate"]),
      last_event: last_event(payload),
      checked_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      raw: payload
    }
  end

  defp first_of(payload, keys) do
    Enum.find_value(keys, fn k ->
      case Map.get(payload, k) do
        v when is_binary(v) and v != "" -> v
        _ -> nil
      end
    end)
  end

  defp delivered?(payload) do
    text =
      [first_of(payload, ["status", "statusSummary", "statusCategory"]) || ""]
      |> Enum.join(" ")
      |> String.downcase()

    String.contains?(text, "delivered")
  end

  defp last_event(payload) do
    events =
      Enum.find_value(["trackingEvents", "eventSummaries", "events"], [], fn k ->
        case Map.get(payload, k) do
          list when is_list(list) and list != [] -> list
          _ -> nil
        end
      end)

    case events do
      [first | _] when is_map(first) ->
        %{
          type: first_of(first, ["eventType", "event", "eventCode"]),
          at: first_of(first, ["eventTimestamp", "eventDateTime", "eventDate"]),
          where:
            [first_of(first, ["eventCity"]), first_of(first, ["eventState"])]
            |> Enum.reject(&is_nil/1)
            |> Enum.join(", ")
        }

      [first | _] when is_binary(first) ->
        %{type: nil, at: nil, where: nil, text: first}

      _ ->
        nil
    end
  end

  # --- subscriptions -----------------------------------------------------
  #
  # Operational facts from the spec that shape the design:
  #   * `secret` must be exactly 32 characters.
  #   * A subscription is deleted after 30 days with no traffic to the listener
  #     (warning email at 25), so it has to be recreated, not set once.
  #   * At most 10 unique listener URLs per CRID -- so one shared listener for
  #     every parcel, not one per parcel.
  #   * USPS flips a subscription to SUSPENDED if the listener is unreachable.

  @subscriptions_default "https://apis.usps.com"

  def subscriptions_base,
    do: Application.get_env(:room_packages, :usps_subscriptions_base, @subscriptions_default)

  @doc """
  Subscribe to events for one tracking number.

  `secret` is used by USPS to HMAC the notification payload; it must be exactly
  32 characters and is what `verify_hmac/4` checks against on the way back in.
  """
  def subscribe(source, number, listener_url, secret, emails, event_types \\ ["ALL_UPDATES"]) do
    with :ok <- validate_secret(secret),
         {:ok, token} <- token(source) do
      body =
        Poison.encode!(%{
          listenerURL: listener_url,
          secret: secret,
          adminNotification: Enum.map(List.wrap(emails), &%{email: &1}),
          filterProperties: %{
            trackingNumber: number,
            trackingEventTypes: event_types
          }
        })

      url = "#{subscriptions_base()}/subscriptions-tracking/v3r2/subscriptions"

      case HTTPoison.post(url, body,
             [
               {"Authorization", "Bearer #{token}"},
               {"Content-Type", "application/json"},
               {"Accept", "application/json"}
             ],
             recv_timeout: 20_000
           ) do
        # POST is idempotent by design: USPS de-duplicates rather than erroring.
        {:ok, %{status_code: code, body: raw}} when code in [200, 201] ->
          {:ok, Poison.decode!(raw)}

        {:ok, %{status_code: 401, body: raw}} ->
          Logger.warning("USPS subscribe 401 -- is the subscriptions-tracking scope approved? #{String.slice(raw, 0, 200)}")
          {:error, :unauthorized}

        {:ok, %{status_code: code, body: raw}} ->
          Logger.warning("USPS subscribe HTTP #{code}: #{String.slice(raw, 0, 300)}")
          {:error, {:http, code}}

        {:error, err} ->
          {:error, err.reason}
      end
    end
  end

  defp validate_secret(secret) when is_binary(secret) do
    if String.length(secret) == 32, do: :ok, else: {:error, :secret_must_be_32_chars}
  end

  defp validate_secret(_), do: {:error, :secret_must_be_32_chars}

  @doc "A conforming 32-character secret."
  def generate_secret, do: :crypto.strong_rand_bytes(24) |> Base.encode64() |> binary_part(0, 32)

  @doc """
  Check the `X-HMAC` header on an inbound notification.

  Per the spec: concatenate the timestamp and the raw payload string, HMAC with
  the shared secret using SHA-256, and Base64 the result.

  Compared in constant time -- a timing-variable compare on a signature is how
  forgery oracles happen.
  """
  def verify_hmac(header_value, timestamp, payload, secret)
      when is_binary(header_value) and is_binary(timestamp) and is_binary(payload) and
             is_binary(secret) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, timestamp <> payload)
      |> Base.encode64()

    Plug.Crypto.secure_compare(header_value, expected)
  end

  def verify_hmac(_, _, _, _), do: false

  @doc """
  Unwrap a pushed notification.

  The interesting part arrives as a JSON string *inside* the JSON envelope, so
  it needs decoding twice.
  """
  def parse_notification(%{"payload" => payload} = envelope) when is_binary(payload) do
    case Poison.decode(payload) do
      {:ok, decoded} ->
        {:ok,
         %{
           subscription_id: envelope["subscriptionId"],
           timestamp: envelope["timestamp"],
           number: decoded["trackingNumber"],
           summary: summarise(decoded, decoded["trackingNumber"])
         }}

      {:error, _} ->
        {:error, :bad_payload}
    end
  end

  def parse_notification(_), do: {:error, :bad_envelope}

  defp to_int(v, _default) when is_integer(v), do: v

  defp to_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_int(_, default), do: default
end
