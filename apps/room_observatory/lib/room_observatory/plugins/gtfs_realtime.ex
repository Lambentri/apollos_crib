defmodule RoomObservatory.Plugins.GtfsRealtime do
  @moduledoc """
  Whether each GTFS-realtime feed is actually working.

  ## The signal that matters

  `last_success_age_seconds` is the one to alert on. A feed reports every
  thirty seconds, so this sits near zero and climbs the moment anything goes
  wrong -- and, unlike an error rate, it climbs for the failure that produces
  no errors at all: a worker that died, a source that stopped being polled, a
  URL nobody is fetching. Silence and health look identical in a log; they look
  nothing alike here.

  It is deliberately not "seconds since the last failure". A feed that fails
  once and recovers is uninteresting; a feed whose last success was an hour ago
  is broken whatever it has been logging since.

  ## The others

  `entities` distinguishes a feed answering with nothing from one not
  answering. An agency's overnight trip feed legitimately empties out, so this
  is context rather than an alert.

  `unnamed_extension_fields` counts the bytes the decoder kept but could not
  name -- protobuf fields at tag numbers no loaded extension claims. Zero means
  every field in the feed has a definition behind it. A number appearing where
  there was none is the earliest possible warning that an agency has started
  publishing something being dropped on the floor, which is otherwise entirely
  invisible. MTA Bus vehicle positions sit at a few thousand today, from an
  extension at tag 1006 that has no published definition.

  `ok` is the last attempt, 1 or 0. The reason a fetch failed is in the logs
  rather than a label here: reasons are open-ended, and a label that takes
  arbitrary values from an HTTP client is how a metrics store gets a million
  series it can never drop.

  ## Reading the labels

  `kind` is `sa`, `tu` or `vp` -- service alerts, trip updates, vehicle
  positions. All three carrying identical numbers is worth a second look: it
  usually means a source has the same URL in all three config fields, which is
  correct for a subway feed carrying trip updates and vehicle positions
  together, and a mistake for service alerts.
  """

  use PromEx.Plugin

  require Logger

  @event [:room_observatory, :gtfs_realtime, :feed]

  @poll_rate :timer.seconds(30)

  @impl true
  def polling_metrics(opts) do
    prefix = Keyword.get(opts, :metric_prefix, [:room_observatory, :gtfsrt])
    poll_rate = Keyword.get(opts, :poll_rate, @poll_rate)

    Polling.build(
      :gtfs_realtime_polling_events,
      poll_rate,
      {__MODULE__, :execute_metrics, []},
      [
        last_value(
          prefix ++ [:last_success_age_seconds],
          event_name: @event,
          measurement: :last_success_age,
          description:
            "Seconds since this feed was last fetched successfully. Climbs for a feed that is failing and for one that stopped being polled at all.",
          tags: [:source, :kind]
        ),
        last_value(
          prefix ++ [:entities],
          event_name: @event,
          measurement: :entities,
          description: "Entities in the last successful fetch.",
          tags: [:source, :kind]
        ),
        last_value(
          prefix ++ [:unnamed_extension_fields],
          event_name: @event,
          measurement: :extensions,
          description:
            "Protobuf fields kept but not named by any loaded extension. Zero is healthy; a number appearing is data being dropped.",
          tags: [:source, :kind]
        ),
        last_value(
          prefix ++ [:ok],
          event_name: @event,
          measurement: :ok,
          description: "1 if the last fetch succeeded, 0 if it did not. Why is in the logs.",
          tags: [:source, :kind]
        ),
        last_value(
          prefix ++ [:fetch_duration_milliseconds],
          event_name: @event,
          measurement: :duration_ms,
          description:
            "How long the last fetch took. A feed served from the shared cache reports single-digit milliseconds.",
          tags: [:source, :kind]
        )
      ],
      detach_on_error: false
    )
  end

  @doc false
  def execute_metrics do
    for record <- RoomGtfs.FeedHealth.all() do
      :telemetry.execute(
        @event,
        %{
          # A feed that has never once succeeded has no age to report. -1 rather
          # than a gap, so "never worked" is visible on a graph instead of being
          # an absent series that reads like a healthy one.
          last_success_age: age_of(record.last_success_at),
          entities: record.entities || 0,
          extensions: record.extensions || 0,
          ok: if(record.ok, do: 1, else: 0),
          duration_ms: record.duration_ms || 0
        },
        %{source: record.source_name || "source #{record.source_id}", kind: record.kind}
      )
    end

    :ok
  rescue
    error -> log_skipped(error)
  catch
    :exit, reason -> log_skipped(reason)
  end

  defp age_of(nil), do: -1
  defp age_of(at), do: System.system_time(:second) - at

  defp log_skipped(reason) do
    Logger.warning("RoomObservatory.Plugins.GtfsRealtime skipped: #{inspect(reason)}")
    :ok
  end
end
