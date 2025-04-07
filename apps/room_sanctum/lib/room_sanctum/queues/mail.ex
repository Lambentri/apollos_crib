defmodule RoomSanctum.Queues.Mail do
  require Logger
  use Oban.Worker, queue: :emails

  @ups_regex ~r/\b1Z[A-Z0-9]{16}\b/
  @fedex_regex ~r/\b([0-9]{12}|100\d{31}|\d{15}|\d{18}|96\d{20}|96\d{32})\b/
  @usps_regex ~r/\b([A-Z]{2}\d{9}[A-Z]{2}|(420\d{9}(9[2345])?)?\d{20}|(420\d{5})?(9[12345])?(\d{24}|\d{20})|82\d{8})\b/
  @uniuni_regex ~r/\bUUSC[0-9]{12}\b/

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "mail" => %{
              "Date" => date,
              "From" => from_m,
              "Subject" => subject,
              "To" => to_m,
              "html_body" => html_body,
              "plain_body" => plain_body
            },
            "from" => from,
            "to" => to
          } = args
      }) do
    IO.inspect({"mmmm", from, subject, to})
    to_addr = String.split(List.first(to), "@") |> List.first()

    case RoomSanctum.Configuration.get_taxid(:user, to_addr) do
      nil ->
        IO.inspect({"Mailer: Unhandled email found", to_addr})

      taxid ->
        # get adjacent webhook urls

        IO.inspect(taxid.source_id)

        case taxid.designator do
          "mail_main" ->
            extracted =
              Map.merge(
                extract_tracking(plain_body),
                extract_tracking(html_body),
                fn _k, v1, v2 -> v1 ++ v2 end
              )
              |> Enum.map(fn {k, v} -> {k, v |> MapSet.new() |> MapSet.to_list()} end)
              |> Map.new()
              |> IO.inspect()
              |> Enum.map(fn {k, v} ->
                IO.inspect({k, v})

                case k do
                  :ups ->
                    ag = RoomSanctum.Configuration.get_agyr!(:src, taxid.source_id, "ups_webhook")
                    register_ups(v, ag)

                  :fedex ->
                    register_fedex(v)

                  :usps ->
                    register_usps(v)

                  :uniuni ->
                    register_uniuni(v)

                  _otherwise ->
                    IO.inspect({"owowowow", k, v})
                end
              end)

          "mail_usps" ->
            :usps
        end

        %{meta: args, body_plain: plain_body, body_html: html_body, mail: taxid.id}
        |> RoomSanctum.Storage.create_taxidae()
    end

    # save

    :ok
  end

  def extract_tracking(body) do
    cond do
      String.match?(body, @usps_regex) -> %{usps: Regex.run(@usps_regex, body)}
      String.match?(body, @ups_regex) -> %{ups: Regex.run(@ups_regex, body)}
      String.match?(body, @fedex_regex) -> %{fedex: Regex.run(@fedex_regex, body)}
      String.match?(body, @uniuni_regex) -> %{uniuni: Regex.run(@uniuni_regex, body)}
      true -> %{nothing: []}
    end
  end

  def build_webhookurl(scheme, host, agyr) do
    "#{scheme}#{host}/api/data/#{agyr.path}"
  end

  def can_ups_token(agyr) do
    source = RoomSanctum.Configuration.get_source!(agyr.source_id)
    conf = source.config

    case {conf.apikey_ups_id != nil, conf.apikey_ups_secret != nil} do
      {true, true} -> true
      _otherwise -> false
    end
  end

  def need_to_ups_token(agyr) do
    source = RoomSanctum.Configuration.get_source!(agyr.source_id)
    conf = source.config
    now = DateTime.now!("UTC")

    case conf.token_ups_expiry do
      nil ->
        true

      _otherwise ->
        {:ok, token_expiry, _extra} = DateTime.from_iso8601(conf.token_ups_expiry)
        IO.inspect({"tetete", token_expiry, now, now > token_expiry})
        comp = DateTime.compare(token_expiry,now)
        comp == :lt
    end
  end

  def update_ups(agyr) do
    source = RoomSanctum.Configuration.get_source!(agyr.source_id)
    conf = source.config

    url = "https://onlinetools.ups.com/security/v1/oauth/token"
    #    url = "https://wwwcie.ups.com/security/v1/oauth/token"

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization",
       "Basic #{Base.encode64("#{conf.apikey_ups_id}:#{conf.apikey_ups_secret}")}"}
    ]

    body = "grant_type=client_credentials"
    #    body = "username=#{conf.apikey_ups_id};password=#{conf.apikey_ups_secret}"
    case HTTPoison.post(url, body, headers) do
      {:ok, result} ->
        case result.status_code do
          200 ->
            now = DateTime.now!("UTC")
            decoded = result.body |> Poison.decode!()
            access_token = decoded |> Map.get("access_token")
            expiry_seconds = decoded |> Map.get("expires_in")

            expiry_time =
              now
              |> DateTime.add(seconds = String.to_integer(expiry_seconds))
              |> DateTime.to_iso8601()

            update = %{token_ups: access_token, token_ups_expiry: expiry_time}
            RoomSanctum.Configuration.update_source_config(source, update)
            {:ok, access_token}

          otherwise ->
            Logger.error(result.body)
            {:error, :http_status_code}
        end

      {:error, reason} ->
        Logger.error(reason)
        {:error, :http_bad_req}
    end
  end

  def register_ups(trackings, agyr) do
    case can_ups_token(agyr) do
      true ->
        source = RoomSanctum.Configuration.get_source!(agyr.source_id)

        {:ok, token} =
          case need_to_ups_token(agyr) do
            true -> update_ups(agyr)
            false -> {:ok, source.config.token_ups}
          end

        trackings
        |> Enum.map(fn t ->
          RoomSanctum.Configuration.create_source_meta_tracking(source, t, :ups)
        end)

        our_scheme =
          case Application.get_env(:room_sanctum, :env) do
            :dev -> "http://"
            :prod -> "https://"
          end

        our_host = Application.get_env(:room_sanctum, :host)
        our_url = build_webhookurl(our_scheme, our_host, agyr)
        our_creds = "#{agyr.user}:#{agyr.token}"

        type = "standard"
        version = "v1"
        # "https://wwwcie.ups.com/api/track/" 
        url =
          "https://onlinetools.ups.com/api/track/" <>
            version <> "/subscription/" <> type <> "/package"

        #        url = "http://e6166b4a-082f-487f-81b8-125e1b55cf27:cf098949-a9b3-499e-9efa-784336fc261f@localhost:4002/api/data/cef8601a-229a-4d72-b16d-a52c64638aa0"

        payload =
          %{
            "locale" => "en_US",
            "countryCode" => "US",
            "trackingNumberList" => trackings,
            "eventPreference" => [
              "string"
            ],
            "destination" => %{
              "url" => our_url,
              "credentialType" => "Bearer",
              "credential" => our_creds
            }
          }
          |> Poison.encode!()

        res =
          HTTPoison.post(url, payload, [
            {"Content-Type", "application/json"},
            {"transId", "ACT-#{DateTime.now!("UTC") |> DateTime.to_unix()}"},
            {"transactionSrc", "apollos-crib-tracker"},
            {"Authorization", "Bearer #{token}"}
          ])

        IO.inspect({"ups-post", res, url, payload})

      false ->
        Logger.info("Source #{agyr.source_id} missing API keys for UPS")
    end
  end

  def register_fedex(tracking) do
  end

  def register_usps(tracking) do
  end

  def register_uniuni(tracking) do
  end
end
