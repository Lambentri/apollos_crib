defmodule RoomCalendar.Worker do
  @moduledoc false
  use GenServer

  require Logger

  import Ecto.Query, only: [from: 2]

  alias RoomCalendar.Occurrences
  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Storage.ICalendar
  alias RoomSanctum.Repo

  @registry :zeus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("ical" <> opts[:name]))
  end

  def init(opts) do
    {:ok, %{id: opts[:name]}}
  end

  # public
  def refresh_db_cfg(name) do
    "ical#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def update_static_data(name) do
    "ical#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_static)
  end

  def update_realtime_data(name) do
    "ical#{name}"
    |> via_tuple()
    |> GenServer.cast(:update_realtime)
  end

  def query_calendar(id, query) do
    Storage.get_upcoming_calendar_entries(id, query)
  end

  defp intify(val) when is_binary(val) do
    val |> String.to_integer()
  end

  defp intify(val) do
    val
  end

  # How far either side of now a repeating event is written out. Back far
  # enough that this week's dates are there whatever day it is; ahead as far
  # as any board looks.
  @days_back 30
  @days_ahead 365

  def handle_cast(:update_static, state) do
    Logger.info("iCAL::#{state.id} updating")
    cfg = Configuration.get_source!(state.id)

    case fetch(cfg.config.url) do
      {:ok, events} ->
        count = store(intify(state.id), window(events))
        Logger.info("iCAL::#{state.id} stored #{count} occurrences of #{length(events)} events")

      {:error, reason} ->
        Logger.warning("iCAL::#{state.id} #{reason}")
    end

    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # The source's rows are the feed as it is now: replaced, not added to. Rows
  # were once upserted on their whole content, so a moved or retitled event
  # left its old self behind for ever.
  defp store(source_id, occurrences) do
    dt = NaiveDateTime.local_now()

    rows =
      Enum.map(occurrences, fn o ->
        %{
          source_id: source_id,
          date_start: o.start,
          date_end: o.end,
          blob: blob(o),
          inserted_at: dt,
          updated_at: dt
        }
      end)

    {:ok, count} =
      Repo.transaction(fn ->
        Repo.delete_all(from(ic in ICalendar, where: ic.source_id == ^source_id))

        rows
        |> Enum.chunk_every(1_000)
        |> Enum.reduce(0, fn chunk, n ->
          # A feed listing the same event twice is one row, not a failed update.
          {k, _} = Repo.insert_all(ICalendar, chunk, on_conflict: :nothing)
          n + k
        end)
      end)

    count
  end

  # What the condensers and pages read. The start goes in too: every date of a
  # series is otherwise the same blob, and a source's blobs are unique.
  defp blob(o) do
    %{
      "summary" => o.summary,
      "description" => o.description,
      "location" => o.location,
      "uid" => o.uid,
      "all_day" => o.all_day,
      "rrule" => o.rrule,
      "occurrence" => DateTime.to_iso8601(o.start)
    }
  end

  defp window(events) do
    now = DateTime.utc_now()
    Occurrences.expand(events, DateTime.add(now, -@days_back, :day), DateTime.add(now, @days_ahead, :day))
  end

  @doc """
  Fetch and parse a feed without storing anything.

  `{:ok, events}` or `{:error, reason}`, the reason a sentence a person can
  act on. A page that is not iCalendar at all -- a provider's "subscribe"
  widget is the usual one -- parses to no events rather than failing, so it is
  caught here before it can look like an empty calendar.
  """
  def fetch(url) do
    url = String.replace(url, "webcal://", "https://")

    case HTTPoison.get(url, [], follow_redirect: true, recv_timeout: 15_000) do
      {:ok, %{status_code: 200, body: body} = resp} ->
        if String.contains?(body, "BEGIN:VCALENDAR") do
          parse(body)
        else
          {:error, "not an iCalendar feed (got #{content_type(resp)}, no BEGIN:VCALENDAR)"}
        end

      {:ok, %{status_code: code}} ->
        {:error, "HTTP #{code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "request failed: #{inspect(reason)}"}
    end
  end

  defp parse(body) do
    {:ok, ICal.from_ics(body).events}
  rescue
    e -> {:error, "could not read the feed: #{Exception.message(e)}"}
  end

  @doc """
  What a feed holds that is not over yet: the next `limit` occurrences, with
  repeating events written out, and the counts around them -- for checking a
  URL before (or instead of) storing it.
  """
  def preview(url, limit \\ 15) do
    with {:ok, events} <- fetch(url) do
      now = DateTime.utc_now()

      upcoming =
        events
        |> window()
        # Not yet over, so today's all-day events -- midnight UTC -- stay in.
        |> Enum.filter(&(DateTime.compare(&1.end || &1.start, now) == :gt))

      {:ok,
       %{
         total: length(events),
         upcoming: length(upcoming),
         recurring: Enum.count(events, &(&1.rrule && is_nil(&1.recurrence_id))),
         events: Enum.take(upcoming, limit)
       }}
    end
  end

  defp content_type(%{headers: headers}) do
    Enum.find_value(headers, "unknown content", fn {k, v} ->
      if String.downcase(k) == "content-type", do: v
    end)
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
