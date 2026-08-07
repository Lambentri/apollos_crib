defmodule RoomHermes.Mail.Supervisor do
  use Supervisor

  require Logger

  @moduledoc """
  Decides whether the SMTP listener runs.

      config :room_hermes, :mail_ingest, :imap   # default -- no listener
      config :room_hermes, :mail_ingest, :smtp
      config :room_hermes, :mail_ingest, :both

  IMAP polling is not started here: a `:mailbox` source gets its own worker from
  `RoomZeus.DynSupervisor`, the same as every other source type. `:imap` simply
  means "do not bind the SMTP port".
  """

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    mode = ingest_mode()
    Logger.info("Mail ingest mode: #{mode}")

    children = if mode in [:smtp, :both], do: [smtp_child()], else: []

    Supervisor.init(children, strategy: :one_for_one)
  end

  def ingest_mode do
    case Application.get_env(:room_hermes, :mail_ingest, :imap) do
      :smtp -> :smtp
      :both -> :both
      _ -> :imap
    end
  end

  # Transient: a bound port or bad config should not take the app down.
  defp smtp_child do
    %{
      id: RoomHermes.Mail.SmtpServer,
      start: {RoomHermes.Mail.SmtpServer, :start_link, []},
      restart: :transient
    }
  end
end
