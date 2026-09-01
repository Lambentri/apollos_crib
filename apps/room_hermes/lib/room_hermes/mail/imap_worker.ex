defmodule RoomHermes.Mail.ImapWorker do
  @moduledoc """
  One poller per `:mailbox` source, started by `RoomZeus.DynSupervisor` the same
  way every other source type gets a worker.

  Ordering matters: a message is parsed and enqueued *before* it is marked
  `\\Seen`. If anything fails in between, the message stays unread and is picked
  up next cycle. That makes delivery at-least-once rather than at-most-once,
  which is the right way round when the alternative is an untracked parcel.

  The mailbox itself does not know what to do with mail. Consumers point at it
  -- a packages source sets `mailbox_source_id` -- and each message is fanned out
  to every consumer referencing this mailbox.
  """

  use GenServer

  require Logger

  alias RoomHermes.Mail.{IMAP, Parser}
  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Configs.Mailbox

  @registry :zeus
  @interval_seconds 60
  # Bound the first cycle against a mailbox with a large unread backlog.
  @max_per_cycle 50

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("mailbox#{opts[:name]}"))
  end

  def init(opts) do
    Periodic.start_link(
      # A backstop rather than a poll: source config changes are rare, and the
      # workers that read them on a tight timer were the load that kept a
      # ten-connection pool saturated. Nothing here needs to notice an edit
      # within ten seconds.
      every: :timer.seconds(60),
      run: fn -> RoomHermes.Mail.ImapWorker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(@interval_seconds),
      run: fn -> RoomHermes.Mail.ImapWorker.poll(opts[:name]) end,
      initial_delay: :timer.seconds(10)
    )

    {:ok, %{id: opts[:name], inst: %{}}}
  end

  def pid(name), do: "mailbox#{name}" |> via_tuple() |> GenServer.whereis()

  def refresh_db_cfg(name), do: GenServer.cast(via_tuple("mailbox#{name}"), :refresh_db_cfg)
  def poll(name), do: GenServer.cast(via_tuple("mailbox#{name}"), :poll)
  def read(name, query), do: GenServer.call(via_tuple("mailbox#{name}"), {:read, query}, 45_000)

  def handle_cast(:refresh_db_cfg, state) do
    {:noreply, Map.put(state, :inst, Configuration.get_source!(state.id))}
  end

  def handle_cast(:poll, %{inst: %{enabled: true} = source} = state) do
    poll_source(source)
    {:noreply, state}
  end

  def handle_cast(:poll, state), do: {:noreply, state}

  # Listing is deliberately its own connection rather than sharing the poller's:
  # a preview refreshing on a page must never be able to interleave with the
  # fetch/mark-seen sequence and leave a message flagged but unqueued.
  def handle_call({:read, query}, _from, %{inst: source} = state) do
    {:reply, list_recent(source, query), state}
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  @doc "Latest messages in the mailbox, newest first. Never marks anything read."
  def list_recent(source, query) do
    count = field(query, :count) || 10
    unread_only = field(query, :unread_only) == true

    case Mailbox.connection(Map.get(source, :config)) do
      nil ->
        []

      config ->
        case IMAP.session(config, fn conn -> IMAP.fetch_recent(conn, count) end) do
          {:ok, _conn, entries} ->
            entries
            |> Enum.filter(fn e -> not unread_only or not e.seen end)
            |> Enum.map(&present/1)

          {:error, reason} ->
            Logger.warning("Mailbox::#{Map.get(source, :id)} list failed: #{inspect(reason)}")
            []

          _ ->
            []
        end
    end
  end

  defp present(entry) do
    %{
      uid: entry.uid,
      seen: entry.seen,
      subject: entry.subject || "(no subject)",
      from: RoomHermes.Mail.Headers.display_name(entry.from),
      from_address: RoomHermes.Mail.Headers.address(entry.from),
      date: entry.date,
      snippet: Map.get(entry, :snippet)
    }
  end

  defp field(query, key) do
    Map.get(query, key) || Map.get(query, Atom.to_string(key))
  end

  @doc """
  Poll one mailbox source. Public so credentials can be exercised by hand rather
  than waiting for the next tick.
  """
  def poll_source(source) do
    case Mailbox.connection(source.config) do
      nil ->
        {:error, :not_configured}

      config ->
        consumers = consumers_of(source.id)

        result =
          IMAP.session(config, fn conn ->
            case IMAP.search_unseen(conn) do
              {:ok, conn, []} ->
                {:ok, 0}

              {:ok, conn, uids} ->
                selected = Enum.take(uids, @max_per_cycle)

                if length(uids) > @max_per_cycle do
                  Logger.info(
                    "Mailbox::#{source.id} #{length(uids)} unread, handling #{@max_per_cycle} this cycle"
                  )
                end

                {_conn, n} =
                  Enum.reduce(selected, {conn, 0}, fn uid, {conn, count} ->
                    case handle_uid(conn, uid, source, consumers) do
                      {:ok, conn} -> {conn, count + 1}
                      {:skip, conn} -> {conn, count}
                    end
                  end)

                {:ok, n}

              {:error, reason} ->
                {:error, reason}
            end
          end)

        record(source, result)
        result
    end
  end

  @doc """
  Routing designators belonging to sources that reference this mailbox.

  A mailbox with no consumers still polls, but nothing is done with the mail --
  which is visible on the source page rather than silently dropped.
  """
  def consumers_of(mailbox_source_id) do
    Configuration.list_cfg_sources()
    |> Enum.filter(fn s ->
      s.enabled and is_map(s.config) and
        Map.get(s.config, :mailbox_source_id) == mailbox_source_id
    end)
    |> Enum.flat_map(fn s ->
      Configuration.get_source!(s.id).mailboxes
      |> Enum.filter(&(&1.designator == "mail_main"))
    end)
  end

  defp handle_uid(conn, uid, source, consumers) do
    with {:ok, conn, raw} <- IMAP.fetch_message(conn, uid),
         mail when is_map(mail) <- Parser.parse(raw) do
      Enum.each(consumers, &enqueue(mail, &1))

      case IMAP.mark_seen(conn, uid) do
        {:ok, conn} ->
          {:ok, conn}

        {:error, reason} ->
          Logger.warning("Mailbox::#{source.id} queued uid #{uid} but could not flag it: #{inspect(reason)}")
          {:ok, conn}
      end
    else
      nil ->
        Logger.warning("Mailbox::#{source.id} could not parse uid #{uid}, leaving unread")
        {:skip, conn}

      {:error, reason} ->
        Logger.warning("Mailbox::#{source.id} uid #{uid} failed: #{inspect(reason)}")
        {:skip, conn}
    end
  end

  defp enqueue(mail, taxid) do
    %{mail: mail, from: from_of(mail), to: to_of(mail), taxid_id: taxid.id}
    |> RoomSanctum.Queues.Mail.new()
    |> Oban.insert()
  end

  defp from_of(%{"From" => %{email: email}}), do: email
  defp from_of(%{"From" => from}) when is_binary(from), do: from
  defp from_of(_), do: ""

  defp to_of(%{"To" => list}) when is_list(list) do
    Enum.map(list, fn
      %{email: email} -> email
      other -> to_string(other)
    end)
  end

  defp to_of(_), do: []

  defp record(source, {:ok, n}) do
    if n > 0, do: Logger.info("Mailbox::#{source.id} queued #{n} message(s)")
    Configuration.update_source_meta(source, %{last_run: DateTime.utc_now()})
  end

  defp record(source, {:error, reason}) do
    Logger.warning("Mailbox::#{source.id} poll failed: #{inspect(reason)}")
  end

  defp record(_source, _), do: :ok

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
