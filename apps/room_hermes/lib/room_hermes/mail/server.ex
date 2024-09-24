defmodule RoomHermes.Mail.Server do
  require Logger
  @behaviour :gen_smtp_server_session

  def init(hostname, session_count, _address, _options) do
    if session_count > 40 do
      Logger.warn("SMTP server connection limit exceeded")
      {:stop, :normal, ["421", hostname, " is too busy to accept mail right now"]}
    else
      banner = [hostname, " Apollos-Mailbag"]
      state = %{}
      {:ok, banner, state}
    end
  end

  def handle_DATA(from, to, data, state) do
    Logger.info("Received DATA:")

    state
    |> Map.put(:body, data)
    |> IO.inspect()

    mail = parse_mail(data, state)
    %{mail: mail, from: from, to: to}
    |> RoomSanctum.Queues.Mail.new()
    |> Oban.insert()
#    mail_json = Poison.encode!(mail) |> IO.inspect()

    {:ok, data, state}
  end

  def handle_EHLO(hostname, extensions, state) do
    Logger.info("EHLO from #{hostname}")
    {:ok, extensions, state}
  end

  def handle_HELO(hostname, state) do
    Logger.info("HELO from #{hostname}")
    {:ok, 655_360, state}
  end

  def handle_MAIL(from, state) do
    Logger.info("MAIL from #{from}")
    {:ok, Map.put(state, :from, from)}
  end

  def handle_RCPT(to, state) do
    Logger.info("RCPT to #{to}")
    {:ok, Map.put(state, :to, to)}
  end

  def handle_VRFY(to, state) do
    fqdn = :smtp_util.guess_FQDN()
    {:ok, "#{to}@#{fqdn}", state}
  end

  @spec handle_other(binary, binary, State.t()) :: {String.t(), State.t()}
  def handle_other(verb, _args, state) do
    {["#{@smtp_unrecognized_command} Error: command not recognized : '", verb, "'"], state}
  end

  def terminate(reason, state) do
    IO.inspect({reason, state})
    {:ok, reason, state}
  end

  defp parse_mail(data, _state) do
    try do
      :mimemail.decode(data, allow_missing_version: true, encoding: "utf-8")
      |> parse_mail_data()
    rescue
      reason ->
        :io.format("Message decode FAILED with ~p:~n", [reason])
    end
  end

  def parse_mail_data(
        {"application" = content_type_name, content_subtype_name, mail_meta, file_info, body}
      ) do
    # handle attachment
  end

  def parse_mail_data({"multipart" = content_type_name, content_subtype_name, mail_meta, _, body}) do
    parse_mail_bodies(body)
    |> Map.merge(extract_mail_meta(mail_meta))
  end

  def parse_mail_data({"text" = content_type_name, content_subtype_name, mail_meta, _, body})
      when content_subtype_name == "plain" or content_subtype_name == "html" do
    meta_data = extract_mail_meta(mail_meta)

    case content_subtype_name do
      "html" -> %{"html_body" => body}
      "plain" -> %{"plain_body" => body}
    end
    |> Map.merge(meta_data)
  end

  defp parse_mail_bodies([], collected), do: collected

  defp parse_mail_bodies([body | bodies], collected \\ %{}) do
    new_collected = Map.merge(collected, parse_mail_data(body))
    parse_mail_bodies(bodies, new_collected)
  end

  defp extract_mail_meta(mail_meta) do
    fields = ["From", "To", "Subject", "Date", "Message-ID"]

    Enum.reduce(fields, %{}, fn field, data ->
      case :proplists.get_value(field, mail_meta) do
        :undefined ->
          data

        value ->
          formatted_value = format_field_value(field, value)
          Map.put(data, field, formatted_value)
      end
    end)
  end

  defp format_field_value("To", value) do
    parse_participants(value)
  end

  defp format_field_value("From", value) do
    parse_participant(value)
  end

  defp format_field_value(_field, value) do
    value
  end

  def parse_participants(participants) when is_binary(participants) do
    participant_list = String.split(participants, ",")
    parse_participants(participant_list, [])
  end

  def parse_participants([], parsed) do
    parsed
  end

  def parse_participants([participant | participants], parsed) do
    participant = String.strip(participant)
    new_parsed = [parse_participant(participant) | parsed]
    parse_participants(participants, new_parsed)
  end

  def parse_participant(participant) do
    parts = String.split(participant, "<")

    case length(parts) do
      1 ->
        %{email: participant}

      2 ->
        email =
          List.last(parts)
          |> String.split(">")
          |> hd
          |> String.strip()

        name = hd(parts) |> String.strip()
        %{name: name, email: email}
    end
  end
end
