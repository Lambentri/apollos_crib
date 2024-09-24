defmodule RoomHermes.Mail.SmtpServer do
  def start_link do
#    session_options = [callbackoptions: [parse: true]]
#    smtp_port = Application.get_env(:messenger, :smtp_opts)
#    smtp_server_options = [[port: smtp_port, sessionoptions: session_options]]
    opts = Application.get_env(:messenger, :smtp_opts) |> IO.inspect
    :gen_smtp_server.start(RoomHermes.Mail.Server, opts)
  end
end