defmodule RoomObservatory.Plugins.Sanctum do
  @moduledoc """
  What room_sanctum is actually holding: how many sources of each kind are
  configured, and how many rows their ingestion has left behind.

  Nothing here is derived from a request or a job. These are inventory
  questions — "how many GTFS feeds are we running", "is gtfs_stop_times still
  growing" — that only the database can answer, so all three metrics are
  polled rather than driven by `:telemetry` events the app already emits.

  ## Three metrics, two poll rates, and why they are not one metric

  `phx_sanctum_sources_count{type, enabled}` is a `GROUP BY` over
  `cfg_sources`, which has tens of rows. Cheap at any rate.

  `phx_sanctum_storage_rows_estimate{table}` is **not** `count(*)`. It reads
  `pg_class.reltuples`, the planner's estimate, for every storage table in one
  query that touches no user table at all. An exact count of gtfs_stop_times is
  a full sequential scan over millions of rows; doing that every 30 seconds
  would make the metric the most expensive thing the database does. The
  estimate is refreshed by autovacuum's ANALYZE, so it lags a bulk GTFS import
  by minutes and is off by a percent or two in steady state — which is the
  right trade for a number whose purpose is watching a trend line.

  `phx_sanctum_storage_source_rows{table, source_id, source, type}` *is* the
  exact `count(*)`, grouped by source, and it is the one that answers "which
  feed is eating the disk". It is also the one that scans. It polls every 15
  minutes by default and lives in its own polling group, so its slow query
  runs in its own poller process and cannot delay the cheap metrics above.

  ## Tables with no source, and rows with no source

  `icarus_flight_watches` is keyed on a flight instance rather than on a
  source — several queries watching the same arrival share one watch — so it
  appears in the estimate metric and is absent from the per-source one.

  `storage_mail` hangs off `cfg_mailboxes`, not off a source directly, so it
  reaches its source through that join.

  A row whose `source_id` is NULL is reported under `source_id="none"`. That is
  deliberate rather than filtered out: orphaned rows left behind by a deleted
  source are exactly the kind of thing this metric exists to surface.

  ## Where the numbers go stale

  A gauge keyed by label keeps its last value until the process restarts, and
  neither Prometheus nor PromEx has a way to say "this series no longer
  exists". Two consequences worth knowing before trusting a panel:

    * Deleting a source leaves its `storage_source_rows` series frozen at its
      final value. Zeroes are filled in for every *existing* source of a
      table's kind on every poll, so an emptied feed does drop to zero — but a
      deleted one does not, until the pod restarts.

    * If a kind has no sources at all, its tables are not counted. That is the
      point: no GTFS feeds means no reason to scan gtfs_stop_times. The
      estimate metric still reports those tables, so orphaned rows stay
      visible there.
  """

  use PromEx.Plugin

  require Logger

  alias RoomSanctum.Repo

  @inventory_event [:room_observatory, :sanctum, :inventory]
  @rows_event [:room_observatory, :sanctum, :storage, :rows]
  @source_rows_event [:room_observatory, :sanctum, :storage, :source_rows]

  @inventory_poll_rate :timer.seconds(30)
  @source_rows_poll_rate :timer.minutes(15)

  # Long enough that a full scan of gtfs_stop_times on a cold cache does not
  # trip the 15s default and leave a permanent hole in the metric.
  @count_timeout :timer.minutes(2)

  # Every table under RoomSanctum.Storage, with the source type that fills it
  # and how a row reaches its source. `:column` is a plain `source_id`;
  # `:via_mailbox` joins through cfg_mailboxes; `:none` means the table has no
  # source at all and is estimate-only.
  @tables [
    %{table: "airnow_hourly_data", type: :aqi, via: :column},
    %{table: "airnow_hourly_observations", type: :aqi, via: :column},
    %{table: "airnow_monitoring_sites", type: :aqi, via: :column},
    %{table: "airnow_reporting_area", type: :aqi, via: :column},
    %{table: "gbfs_alerts", type: :gbfs, via: :column},
    %{table: "gbfs_ebikes_stations", type: :gbfs, via: :column},
    %{table: "gbfs_free_bike_status", type: :gbfs, via: :column},
    %{table: "gbfs_geofencing_zones", type: :gbfs, via: :column},
    %{table: "gbfs_station_information", type: :gbfs, via: :column},
    %{table: "gbfs_station_status", type: :gbfs, via: :column},
    %{table: "gbfs_system_information", type: :gbfs, via: :column},
    %{table: "gbfs_system_pricing_plans", type: :gbfs, via: :column},
    %{table: "gbfs_vehicle_types", type: :gbfs, via: :column},
    %{table: "gtfs_agencies", type: :gtfs, via: :column},
    %{table: "gtfs_calendars", type: :gtfs, via: :column},
    %{table: "gtfs_directions", type: :gtfs, via: :column},
    %{table: "gtfs_routes", type: :gtfs, via: :column},
    %{table: "gtfs_shapes", type: :gtfs, via: :column},
    %{table: "gtfs_stops", type: :gtfs, via: :column},
    %{table: "gtfs_stop_times", type: :gtfs, via: :column},
    %{table: "gtfs_trips", type: :gtfs, via: :column},
    %{table: "icalendar_entries", type: :calendar, via: :column},
    %{table: "storage_mail", type: :mailbox, via: :via_mailbox},
    %{table: "icarus_flight_watches", type: nil, via: :none}
  ]

  @impl true
  def polling_metrics(opts) do
    prefix = Keyword.get(opts, :metric_prefix, [:room_observatory, :sanctum])

    [
      inventory_metrics(prefix, Keyword.get(opts, :poll_rate, @inventory_poll_rate)),
      source_rows_metrics(prefix, Keyword.get(opts, :source_rows_poll_rate, @source_rows_poll_rate))
    ]
  end

  defp inventory_metrics(prefix, poll_rate) do
    Polling.build(
      :sanctum_inventory_polling_events,
      poll_rate,
      {__MODULE__, :execute_inventory_metrics, []},
      [
        last_value(
          prefix ++ [:sources, :count],
          event_name: @inventory_event,
          measurement: :sources,
          description: "Configured sources in cfg_sources, by kind and whether they are enabled.",
          tags: [:type, :enabled]
        ),
        last_value(
          prefix ++ [:storage, :rows, :estimate],
          event_name: @rows_event,
          measurement: :rows,
          description:
            "Planner row estimate (pg_class.reltuples) per storage table. Refreshed by ANALYZE, so it lags a bulk import.",
          tags: [:table]
        )
      ],
      detach_on_error: false
    )
  end

  defp source_rows_metrics(prefix, poll_rate) do
    Polling.build(
      :sanctum_storage_source_rows_polling_events,
      poll_rate,
      {__MODULE__, :execute_source_rows_metrics, []},
      [
        last_value(
          prefix ++ [:storage, :source_rows],
          event_name: @source_rows_event,
          measurement: :rows,
          description: "Exact row count per storage table, attributed to the source that filled it.",
          tags: [:table, :source_id, :source, :type]
        )
      ],
      detach_on_error: false
    )
  end

  @doc false
  def execute_inventory_metrics do
    emit_source_counts()
    emit_row_estimates()
  rescue
    error -> log_skipped(:inventory, error)
  catch
    :exit, reason -> log_skipped(:inventory, reason)
  end

  @doc false
  def execute_source_rows_metrics do
    case sources_by_id() do
      empty when map_size(empty) == 0 -> :ok
      sources -> Enum.each(@tables, &safely_emit_source_rows(&1, sources))
    end
  rescue
    error -> log_skipped(:storage_source_rows, error)
  catch
    :exit, reason -> log_skipped(:storage_source_rows, reason)
  end

  # Per table rather than per group: 24 counts are 24 separate queries, and one
  # that fails — a table dropped by a migration, a statement timeout on the
  # largest — should cost its own series, not the 23 behind it in the loop.
  defp safely_emit_source_rows(table, sources) do
    emit_source_rows(table, sources)
  rescue
    error -> log_skipped(table.table, error)
  catch
    :exit, reason -> log_skipped(table.table, reason)
  end

  # -- sources -------------------------------------------------------------

  defp emit_source_counts do
    %{rows: rows} = Repo.query!("SELECT type, enabled, count(*) FROM cfg_sources GROUP BY 1, 2")

    counts = Map.new(rows, fn [type, enabled, count] -> {{type_label(type), enabled}, count} end)

    # Zero-filled across the full enum rather than only the types present, so a
    # kind that drops to zero reads as zero instead of vanishing from the graph.
    types = Enum.uniq(known_types() ++ Enum.map(rows, fn [type, _, _] -> type_label(type) end))

    for type <- types, enabled <- [true, false] do
      :telemetry.execute(
        @inventory_event,
        %{sources: Map.get(counts, {type, enabled}, 0)},
        %{type: type, enabled: enabled}
      )
    end
  end

  defp known_types do
    RoomSanctum.Configuration.Source
    |> Ecto.Enum.values(:type)
    |> Enum.map(&Atom.to_string/1)
  end

  defp type_label(nil), do: "unknown"
  defp type_label(type), do: to_string(type)

  # -- estimates -----------------------------------------------------------

  @estimate_query """
  SELECT c.relname::text, GREATEST(c.reltuples, 0)::bigint
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = current_schema()
    AND c.relkind = 'r'
    AND c.relname::text = ANY($1)
  """

  defp emit_row_estimates do
    names = Enum.map(@tables, & &1.table)
    %{rows: rows} = Repo.query!(@estimate_query, [names])
    estimates = Map.new(rows, fn [table, estimate] -> {table, estimate} end)

    # A table missing from pg_class has not been migrated yet; report 0 rather
    # than leaving a gap, so the series exists from the first scrape.
    for table <- names do
      :telemetry.execute(@rows_event, %{rows: Map.get(estimates, table, 0)}, %{table: table})
    end
  end

  # -- exact per-source counts ---------------------------------------------

  defp sources_by_id do
    %{rows: rows} = Repo.query!("SELECT id, name, type FROM cfg_sources")

    Map.new(rows, fn [id, name, type] ->
      {id, %{name: name || "(unnamed)", type: type_label(type)}}
    end)
  end

  defp emit_source_rows(%{via: :none}, _sources), do: :ok

  defp emit_source_rows(%{type: type} = table, sources) do
    expected = for {id, source} <- sources, source.type == to_string(type), do: {id, source}

    # No feeds of this kind means nothing to attribute, and scanning millions of
    # leftover rows to say so is the cost this guard exists to avoid.
    if expected == [] do
      :ok
    else
      counts = count_by_source(table)

      for [source_id, count] <- counts do
        emit_source_row(table.table, source_id, count, sources, type)
      end

      counted = MapSet.new(counts, fn [source_id, _] -> source_id end)

      for {id, source} <- expected, not MapSet.member?(counted, id) do
        emit(table.table, to_string(id), source.name, source.type, 0)
      end
    end
  end

  defp count_by_source(%{table: table, via: :column}) do
    %{rows: rows} =
      Repo.query!(~s|SELECT source_id, count(*) FROM "#{table}" GROUP BY 1|, [],
        timeout: @count_timeout
      )

    rows
  end

  # The foreign key is `mail`, not `mail_id` — the migration named it that way
  # while `belongs_to :mail` in the schema implies the suffixed name. Raw SQL
  # here has to follow the column that actually exists.
  defp count_by_source(%{via: :via_mailbox}) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT m.source_id, count(*)
        FROM storage_mail s
        JOIN cfg_mailboxes m ON m.id = s.mail
        GROUP BY 1
        """,
        [],
        timeout: @count_timeout
      )

    rows
  end

  defp emit_source_row(table, nil, count, _sources, type) do
    emit(table, "none", "(unassigned)", type_label(type), count)
  end

  defp emit_source_row(table, source_id, count, sources, type) do
    source = Map.get(sources, source_id, %{name: "(deleted)", type: type_label(type)})
    emit(table, to_string(source_id), source.name, source.type, count)
  end

  defp emit(table, source_id, source, type, count) do
    :telemetry.execute(@source_rows_event, %{rows: count}, %{
      table: table,
      source_id: source_id,
      source: source,
      type: type
    })
  end

  defp log_skipped(group, reason) do
    Logger.warning(
      "RoomObservatory.Plugins.Sanctum skipped #{group} metrics: #{inspect(reason)}"
    )

    :ok
  end
end
