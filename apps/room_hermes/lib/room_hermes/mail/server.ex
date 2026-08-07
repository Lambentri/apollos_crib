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

  # Parsing lives in RoomHermes.Mail.Parser so the IMAP poller produces the
  # exact same shape from the same raw message.
  defp parse_mail(data, _state), do: RoomHermes.Mail.Parser.parse(data)

  defdelegate parse_mail_data(part), to: RoomHermes.Mail.Parser
  defdelegate parse_participants(value), to: RoomHermes.Mail.Parser
  defdelegate parse_participant(value), to: RoomHermes.Mail.Parser
end
