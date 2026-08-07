defmodule RoomHermes.Mail.IMAP do
  @moduledoc """
  A deliberately small IMAP client: enough to find unread mail, read it, and
  mark it read.

  Written rather than pulled in because the available client libraries deliver
  only mail that arrives while they are connected. That loses anything that
  landed during a restart, and never touches a backlog -- for parcel mail a
  missed message is an untracked package. Polling `SEARCH UNSEEN` has neither
  problem, and `\\Seen` doubles as the idempotency marker.

  Messages are fetched with `BODY.PEEK[]`, which does *not* set `\\Seen`. The
  flag is set only after the caller confirms the message is safely queued, so a
  crash mid-poll re-delivers rather than silently drops.

  Implicit TLS only (the 993 default). STARTTLS on 143 is not implemented.
  """

  require Logger

  @timeout 30_000
  @greeting_timeout 15_000

  defstruct [:socket, :transport, tag: 0, exists: 0]

  @doc """
  Run `fun` against a connected, authenticated, mailbox-selected session, then
  log out and close regardless of outcome.
  """
  def session(config, fun) do
    case connect(config) do
      {:ok, conn} ->
        try do
          with {:ok, conn} <- login(conn, config.username, config.password),
               {:ok, conn} <- select(conn, config.folder) do
            fun.(conn)
          end
        after
          logout(conn)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def connect(%{host: host, port: port, tls: tls}) do
    host = String.to_charlist(host)

    opts = [
      :binary,
      active: false,
      packet: :line,
      # Servers legitimately send lines longer than the default; a literal
      # header line from a large message will exceed it.
      packet_size: 1_000_000
    ]

    result =
      if tls do
        :ssl.connect(
          host,
          port,
          opts ++
            [
              verify: :verify_peer,
              cacerts: :public_key.cacerts_get(),
              depth: 3,
              server_name_indication: host,
              customize_hostname_check: [
                match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
              ]
            ],
          @timeout
        )
      else
        :gen_tcp.connect(host, port, opts, @timeout)
      end

    case result do
      {:ok, socket} ->
        conn = %__MODULE__{socket: socket, transport: if(tls, do: :ssl, else: :tcp)}
        # Server speaks first.
        case recv_line(conn, @greeting_timeout) do
          {:ok, "* OK" <> _} -> {:ok, conn}
          {:ok, other} -> {:error, {:bad_greeting, String.trim(other)}}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, {:connect_failed, reason}}
    end
  end

  def login(conn, username, password) do
    case command(conn, "LOGIN #{quote_str(username)} #{quote_str(password)}") do
      {:ok, conn, _lines} -> {:ok, conn}
      {:error, reason} -> {:error, {:login_failed, reason}}
    end
  end

  def select(conn, folder) do
    case command(conn, "SELECT #{quote_str(folder)}") do
      {:ok, conn, lines} -> {:ok, %{conn | exists: exists_count(lines)}}
      {:error, reason} -> {:error, {:select_failed, reason}}
    end
  end

  # SELECT reports the message count as an untagged "* N EXISTS".
  defp exists_count(lines) do
    Enum.find_value(lines, 0, fn
      line when is_binary(line) ->
        case Regex.run(~r/^\* (\d+) EXISTS/i, line) do
          [_, n] -> String.to_integer(n)
          nil -> nil
        end

      _ ->
        nil
    end)
  end

  @doc "UIDs of unread messages, oldest first."
  def search_unseen(conn) do
    case command(conn, "UID SEARCH UNSEEN") do
      {:ok, conn, lines} ->
        uids =
          lines
          |> Enum.filter(&String.match?(&1, ~r/^\* SEARCH/i))
          |> Enum.flat_map(fn line ->
            line
            |> String.replace(~r/^\* SEARCH/i, "")
            |> String.split(~r/\s+/, trim: true)
            |> Enum.flat_map(fn tok ->
              case Integer.parse(tok) do
                {n, ""} -> [n]
                _ -> []
              end
            end)
          end)
          |> Enum.sort()

        {:ok, conn, uids}

      {:error, reason} ->
        {:error, {:search_failed, reason}}
    end
  end

  @doc """
  Fetch one message's raw source without marking it read.
  """
  def fetch_message(conn, uid) do
    case command(conn, "UID FETCH #{uid} (BODY.PEEK[])") do
      {:ok, conn, lines} ->
        case Enum.find(lines, &match?({:literal, _}, &1)) do
          {:literal, body} -> {:ok, conn, body}
          nil -> {:error, {:no_body, uid}}
        end

      {:error, reason} ->
        {:error, {:fetch_failed, reason}}
    end
  end

  @doc """
  The newest `n` messages, headers only.

  Sequence numbers are ordered oldest to newest, so the newest `n` is the tail of
  the range. Only From/Subject/Date are fetched -- listing a mailbox should not
  pull message bodies -- and `BODY.PEEK` keeps it from marking anything read.
  """
  def fetch_recent(conn, n, snippet_bytes \\ 2048)

  def fetch_recent(conn, n, snippet_bytes) when n > 0 do
    case conn.exists do
      0 ->
        {:ok, conn, []}

      total ->
        first = max(total - n + 1, 1)

        # A partial fetch (<0.N>) caps how much body comes back, so a preview
        # costs a couple of kilobytes per message rather than the whole thing.
        parts =
          "UID FLAGS BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)] " <>
            "BODY.PEEK[TEXT]<0.#{snippet_bytes}>"

        case command(conn, "FETCH #{first}:#{total} (#{parts})") do
          # pair_fetches/1 prepends as it walks the ascending sequence numbers,
          # so what comes back is already newest-first.
          {:ok, conn, lines} -> {:ok, conn, pair_fetches(lines)}
          {:error, reason} -> {:error, {:fetch_failed, reason}}
        end
    end
  end

  def fetch_recent(conn, _n, _snippet_bytes), do: {:ok, conn, []}

  # A FETCH response now carries two literals per message -- the header block and
  # the leading slice of body text. Each is announced by the line before it, so
  # they are matched on that rather than on position.
  # collect_fetches/4 flushes each message as the next one starts, so the
  # accumulator already comes out newest-first.
  defp pair_fetches(lines), do: collect_fetches(lines, nil, nil, [])

  defp collect_fetches([], _label, current, acc), do: flush(current, acc)

  defp collect_fetches([line | rest], label, current, acc) when is_binary(line) do
    cond do
      Regex.match?(~r/^\* \d+ FETCH/i, line) ->
        acc = flush(current, acc)

        entry = %{
          uid: capture_int(line, ~r/UID (\d+)/),
          seen: String.contains?(line, "\\Seen"),
          headers: nil,
          text: nil
        }

        collect_fetches(rest, label_of(line), entry, acc)

      current != nil ->
        collect_fetches(rest, label_of(line) || label, current, acc)

      true ->
        collect_fetches(rest, label, current, acc)
    end
  end

  defp collect_fetches([{:literal, data} | rest], label, current, acc) do
    current =
      case {current, label} do
        {nil, _} -> nil
        {c, :text} -> %{c | text: data}
        {c, _} -> %{c | headers: data}
      end

    collect_fetches(rest, nil, current, acc)
  end

  defp collect_fetches([_other | rest], label, current, acc),
    do: collect_fetches(rest, label, current, acc)

  # The trailing "{N}" says a literal follows; what precedes it says which part.
  defp label_of(line) do
    cond do
      not Regex.match?(~r/\{\d+\}$/, line) -> nil
      Regex.match?(~r/BODY\[TEXT\]/i, line) -> :text
      Regex.match?(~r/BODY\[HEADER/i, line) -> :headers
      true -> :headers
    end
  end

  defp flush(nil, acc), do: acc

  defp flush(current, acc) do
    headers = RoomHermes.Mail.Headers.parse(current.headers || "")

    [
      %{
        uid: current.uid,
        seen: current.seen,
        from: headers["from"],
        subject: headers["subject"],
        date: headers["date"],
        snippet: RoomHermes.Mail.Headers.snippet(current.text)
      }
      | acc
    ]
  end

  defp capture_int(line, regex) do
    case Regex.run(regex, line) do
      [_, n] -> String.to_integer(n)
      nil -> nil
    end
  end

  @doc "Mark a message read. Only call once it is safely handed off."
  def mark_seen(conn, uid) do
    case command(conn, "UID STORE #{uid} +FLAGS (\\Seen)") do
      {:ok, conn, _} -> {:ok, conn}
      {:error, reason} -> {:error, {:store_failed, reason}}
    end
  end

  def logout(conn) do
    command(conn, "LOGOUT")
  catch
    _, _ -> :ok
  after
    close(conn)
  end

  @doc """
  Verify credentials without consuming anything: connect, authenticate, open the
  folder, and count what is unread.

  Returns `{:ok, %{unseen: n}}` or `{:error, message}` where the message is
  written for whoever is filling in the form, not for a log file.
  """
  def test_connection(config) do
    case session(config, fn conn ->
           case search_unseen(conn) do
             {:ok, _conn, uids} -> {:ok, %{unseen: length(uids)}}
             {:error, reason} -> {:error, reason}
           end
         end) do
      {:ok, %{unseen: _} = info} -> {:ok, info}
      {:error, reason} -> {:error, describe(reason)}
      other -> {:error, describe(other)}
    end
  end

  @doc "Turn a protocol failure into something actionable."
  def describe({:connect_failed, :nxdomain}), do: "Host not found - check the server address."
  def describe({:connect_failed, :econnrefused}), do: "Connection refused - check the port."
  def describe({:connect_failed, :timeout}), do: "Timed out connecting - check host, port and firewall."
  def describe({:connect_failed, {:tls_alert, _} = alert}), do: "TLS failed: #{inspect(alert)}. If this server uses port 143, turn TLS off."
  def describe({:connect_failed, reason}), do: "Could not connect: #{inspect(reason)}"

  def describe({:login_failed, reason}) do
    text = to_string(inspect(reason))

    if String.contains?(text, "AUTHENTICATIONFAILED") or String.contains?(text, "Invalid") do
      "Server rejected the credentials. Many providers need an app-specific password rather than your account password."
    else
      "Login failed: #{text}"
    end
  end

  def describe({:select_failed, reason}), do: "Could not open that folder: #{inspect(reason)}. Check the folder name."
  def describe({:bad_greeting, text}), do: "Not an IMAP server? It said: #{text}"
  def describe({:search_failed, reason}), do: "Connected, but SEARCH failed: #{inspect(reason)}"
  def describe(other), do: inspect(other)

  # --- protocol plumbing ---

  defp command(conn, command) do
    conn = %{conn | tag: conn.tag + 1}
    tag = "A#{String.pad_leading(Integer.to_string(conn.tag), 4, "0")}"

    case send_data(conn, "#{tag} #{command}\r\n") do
      :ok -> collect(conn, tag, [])
      {:error, reason} -> {:error, {:send_failed, reason}}
    end
  end

  # Reads untagged responses until the tagged completion for this command.
  defp collect(conn, tag, acc) do
    case recv_line(conn) do
      {:error, reason} ->
        {:error, reason}

      {:ok, line} ->
        trimmed = String.trim_trailing(line, "\r\n")

        cond do
          String.starts_with?(trimmed, tag <> " OK") ->
            {:ok, conn, Enum.reverse(acc)}

          String.starts_with?(trimmed, tag <> " ") ->
            {:error, String.trim(trimmed)}

          true ->
            # A line ending in {N} announces exactly N bytes of raw data that
            # are not line-delimited and may contain anything, including CRLFs.
            case Regex.run(~r/\{(\d+)\}$/, trimmed) do
              [_, count] ->
                case read_literal(conn, String.to_integer(count)) do
                  {:ok, literal} -> collect(conn, tag, [{:literal, literal}, trimmed | acc])
                  {:error, reason} -> {:error, reason}
                end

              nil ->
                collect(conn, tag, [trimmed | acc])
            end
        end
    end
  end

  defp read_literal(conn, count) do
    setopts(conn, packet: :raw)

    result =
      case recv(conn, count) do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:error, {:literal_read_failed, reason}}
      end

    setopts(conn, packet: :line)
    result
  end

  defp send_data(%{transport: :ssl, socket: s}, data), do: :ssl.send(s, data)
  defp send_data(%{transport: :tcp, socket: s}, data), do: :gen_tcp.send(s, data)

  defp recv_line(conn, timeout \\ @timeout), do: recv(conn, 0, timeout)

  defp recv(conn, bytes, timeout \\ @timeout)
  defp recv(%{transport: :ssl, socket: s}, bytes, t), do: :ssl.recv(s, bytes, t)
  defp recv(%{transport: :tcp, socket: s}, bytes, t), do: :gen_tcp.recv(s, bytes, t)

  defp setopts(%{transport: :ssl, socket: s}, opts), do: :ssl.setopts(s, opts)
  defp setopts(%{transport: :tcp, socket: s}, opts), do: :inet.setopts(s, opts)

  defp close(%{transport: :ssl, socket: s}), do: :ssl.close(s)
  defp close(%{transport: :tcp, socket: s}), do: :gen_tcp.close(s)

  # IMAP quoted strings escape backslash and double quote, nothing else.
  defp quote_str(value) do
    escaped =
      value
      |> to_string()
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")

    "\"" <> escaped <> "\""
  end

  @doc false
  def __quote_str__(value), do: quote_str(value)
end
