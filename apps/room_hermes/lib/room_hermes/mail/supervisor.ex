defmodule RoomHermes.Mail.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
    worker(RoomHermes.Mail.SmtpServer, [], restart: :transient)

    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
