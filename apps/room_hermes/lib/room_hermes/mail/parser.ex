defmodule RoomHermes.Mail.Parser do
  @moduledoc """
  Turns a raw RFC822 message into the map the mail queue expects.

  Extracted from `RoomHermes.Mail.Server` so the SMTP listener and the IMAP
  poller produce byte-identical output and only one of them has to be right.

  `RoomSanctum.Queues.Mail.perform/1` pattern matches on every one of
  `Date`, `From`, `Subject`, `To`, `html_body` and `plain_body`, so a message
  missing any of them would never match the clause and the job would retry
  forever. Real mailboxes are full of text-only and html-only mail, so the keys
  are always present here, empty when the message did not supply them.
  """

  require Logger

  @defaults %{
    "Date" => "",
    "From" => %{email: ""},
    "Subject" => "",
    "To" => [],
    "plain_body" => "",
    "html_body" => ""
  }

  @doc "Decode a raw message. Returns nil if it cannot be parsed at all."
  def parse(data) do
    decoded =
      :mimemail.decode(data, allow_missing_version: true, encoding: "utf-8")
      |> parse_mail_data()

    Map.merge(@defaults, decoded)
  rescue
    reason ->
      Logger.warning("Mail decode failed: #{inspect(reason)}")
      nil
  end

  # Attachments carry no body we use, but returning nil here would blow up the
  # Map.merge in parse_mail_bodies/2 the moment a message had one.
  def parse_mail_data({"application", _subtype, _meta, _file_info, _body}), do: %{}

  def parse_mail_data({"multipart", _subtype, mail_meta, _, body}) do
    parse_mail_bodies(body)
    |> Map.merge(extract_mail_meta(mail_meta))
  end

  def parse_mail_data({"text", subtype, mail_meta, _, body})
      when subtype == "plain" or subtype == "html" do
    meta_data = extract_mail_meta(mail_meta)

    case subtype do
      "html" -> %{"html_body" => body}
      "plain" -> %{"plain_body" => body}
    end
    |> Map.merge(meta_data)
  end

  # Anything else (inline images, unknown types) contributes no body.
  def parse_mail_data(_), do: %{}

  defp parse_mail_bodies(bodies, collected \\ %{})
  defp parse_mail_bodies([], collected), do: collected

  defp parse_mail_bodies([body | bodies], collected) do
    parse_mail_bodies(bodies, Map.merge(collected, parse_mail_data(body)))
  end

  defp extract_mail_meta(mail_meta) do
    ["From", "To", "Subject", "Date", "Message-ID"]
    |> Enum.reduce(%{}, fn field, data ->
      case :proplists.get_value(field, mail_meta) do
        :undefined -> data
        value -> Map.put(data, field, format_field_value(field, value))
      end
    end)
  end

  defp format_field_value("To", value), do: parse_participants(value)
  defp format_field_value("From", value), do: parse_participant(value)
  defp format_field_value(_field, value), do: value

  def parse_participants(participants) when is_binary(participants) do
    participants
    |> String.split(",")
    |> Enum.map(&parse_participant(String.trim(&1)))
  end

  def parse_participants(_), do: []

  def parse_participant(participant) when is_binary(participant) do
    case String.split(participant, "<") do
      [only] ->
        %{email: String.trim(only)}

      parts ->
        email =
          parts
          |> List.last()
          |> String.split(">")
          |> hd()
          |> String.trim()

        %{name: parts |> hd() |> String.trim(), email: email}
    end
  end

  def parse_participant(other), do: %{email: to_string(other)}
end
