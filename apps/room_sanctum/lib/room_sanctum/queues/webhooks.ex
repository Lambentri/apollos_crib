defmodule RoomSanctum.Queues.Webhooks do
  use Oban.Worker, queue: :webhooks

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"path" => path, "data" => data} = args}) do

    case RoomSanctum.Configuration.get_agyr!(:path, path) do
      nil ->
        IO.inspect("non-extant agyr")

      agyr ->
        source = RoomSanctum.Configuration.get_source!(agyr.source_id)
        case agyr.designator do
          "ups_webhook" ->
            number = data |> Map.get("trackingNumber") |> String.trim()
            RoomSanctum.Configuration.update_source_meta_tracking(source, number, data)

          "usps_webhook" ->
            handle_usps(source, data, args)

          other ->
            Logger.info("Unhandled webhook designator: #{other}")
        end
    end

    #    model = MyApp.Repo.get(MyApp.Business.Man, id)
    #
    #    case args do
    #      %{"in_the" => "business"} ->
    #        IO.inspect(model)
    #
    #      %{"vote_for" => vote} ->
    #        IO.inspect([vote, model])
    #
    #      _ ->
    #        IO.inspect(model)
    #    end

    :ok
  end

  # USPS wraps the interesting part as a JSON string inside the envelope, and
  # signs timestamp <> payload. The signature is checked before anything is
  # written, so an unverified push cannot rewrite a parcel's history.
  defp handle_usps(source, data, args) do
    secret = get_in(source.config |> Map.from_struct(), [:usps_webhook_secret])
    hmac = args["hmac"]

    cond do
      is_binary(secret) and secret != "" and
          not RoomPackages.USPS.verify_hmac(hmac || "", data["timestamp"] || "", data["payload"] || "", secret) ->
        Logger.warning("USPS webhook HMAC mismatch for subscription #{inspect(data["subscriptionId"])} -- ignoring")
        :ok

      true ->
        case RoomPackages.USPS.parse_notification(data) do
          {:ok, %{number: number, summary: summary}} when is_binary(number) ->
            RoomSanctum.Configuration.update_source_meta_tracking(source, number, summary)

          {:ok, _} ->
            Logger.warning("USPS webhook had no tracking number")

          {:error, reason} ->
            Logger.warning("USPS webhook unparseable: #{inspect(reason)}")
        end
    end
  end
end
