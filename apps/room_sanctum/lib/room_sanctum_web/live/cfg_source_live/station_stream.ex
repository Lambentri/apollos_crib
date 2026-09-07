defmodule RoomSanctumWeb.SourceLive.StationStream do
  @moduledoc """
  Reads a source's places in pages and posts them to a LiveView as they arrive.

  A national GTFS feed has stops by the hundred thousand. Fetching them in one
  query took longer than the fifteen second checkout timeout, which killed the
  LiveView -- and it did it on a ten second timer, so the page crashed, came
  back, and crashed again.

  Paging fixes the part that was actually broken. No single query is long
  enough to time out, the connection is returned between pages rather than held
  across the whole read, and the page paints its first twenty thousand stops
  while the rest are still coming.

  ## Why a process rather than a loop in the LiveView

  A LiveView that loops is a LiveView that is not answering anything else --
  no clicks, no ticks, no navigation, until the last page lands. Reading in
  its own process leaves the page live throughout, and the batches arrive as
  ordinary messages it can choose to fold in.

  Linked to the LiveView on purpose: a reader whose page has gone is reading
  for nobody, and should go with it rather than finish a quarter of a million
  rows into a dead mailbox.
  """
  use GenServer, restart: :temporary

  alias RoomSanctumWeb.SourceLive.Stations

  # Big enough that a national feed is tens of queries rather than thousands,
  # small enough that one page is nowhere near the checkout timeout.
  @batch 20_000

  @doc """
  Start reading `source`, posting batches to `to`.

  Sends `{:stations_batch, source_id, stations}` per page and
  `{:stations_done, source_id, total}` at the end.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, Map.new(opts))
  end

  @impl true
  def init(%{source: source, to: to}) do
    {:ok, %{source: source, to: to, cursor: nil, sent: 0}, {:continue, :page}}
  end

  @impl true
  def handle_continue(:page, state) do
    case Stations.page(state.source, state.cursor, @batch) do
      {[], _cursor} ->
        send(state.to, {:stations_done, state.source.id, state.sent})
        {:stop, :normal, state}

      {stations, cursor} ->
        send(state.to, {:stations_batch, state.source.id, stations})

        # Straight on to the next page: `handle_continue` yields between them,
        # so this stays interruptible and the linked LiveView's exit still
        # takes it down mid-read.
        {:noreply, %{state | cursor: cursor, sent: state.sent + length(stations)},
         {:continue, :page}}
    end
  end
end
