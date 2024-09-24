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
                  :fedex -> register_fedex(v)
                  :usps -> register_usps(v)
                  :uniuni -> register_uniuni(v)
                  _otherwise -> IO.inspect({"owowowow", k,v})
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

  def register_ups(trackings, agyr) do

    source = RoomSanctum.Configuration.get_source!(agyr.source_id)
    trackings |> Enum.map(fn t -> RoomSanctum.Configuration.create_source_meta_tracking(source, t, :ups) end)


    our_scheme = case Application.get_env(:room_sanctum, :env) do
      :dev -> "http://"
      :prod -> "https://"
    end
    our_host = Application.get_env(:room_sanctum, RoomSanctumWeb.Endpoint) |> Keyword.get(:url) |> Keyword.get(:host)
    our_url = build_webhookurl(our_scheme, our_host, agyr)
    our_creds = "#{agyr.user}:#{agyr.token}"

    type = "standard"
    version = "v1"

    url = "https://wwwcie.ups.com/api/track/" + version + "/subscription/" + type + "/package"
    #    url = "http://e6166b4a-082f-487f-81b8-125e1b55cf27:cf098949-a9b3-499e-9efa-784336fc261f@localhost:4002/api/data/cef8601a-229a-4d72-b16d-a52c64638aa0"

    payload = %{
      "locale" => "en_US",
      "countryCode" => "US",
      "trackingNumberList" => trackings,
      "eventPreference" => [
        "string"
      ],
      "destination" => %{
        "url" => our_url,
        "credentialType" => "basic",
        "credential" => our_creds
      }
    } |> Poison.encode!

    HTTPoison.post(url, payload, [{"Accept", "application/json"}])
  end

  def register_fedex(tracking) do
  end

  def register_usps(tracking) do
  end

  def register_uniuni(tracking) do
  end
end
