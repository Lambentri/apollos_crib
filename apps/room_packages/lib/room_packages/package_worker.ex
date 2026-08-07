defmodule RoomPackages.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
  alias RoomSanctum.Repo
  require Logger

  @registry :zeus
  @dynamic_refresh_seconds 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("packages" <> opts[:name]))
  end

  @impl true
  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(@dynamic_refresh_seconds),
      run: fn -> RoomPackages.Worker.refresh(opts[:name]) end,
      initial_delay: 10
    )

    {:ok, %{id: opts[:name], data: []}}
  end

  # publiq
  def refresh(name) do
    "packages#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh)
  end

  def read(name, query) do
    "packages#{name}"
    |> via_tuple()
    |> GenServer.call({:read, query})
  end

  def handle_cast(:refresh, state) do
    s = Configuration.get_source!(state[:id])
    poll_usps(s)

    # Re-read: polling appends entries, so the pre-poll copy would be stale.
    s = Configuration.get_source!(state[:id])
    {:noreply, state |> Map.put(:data, s.meta.tracking)}
  end

  # USPS is poll-only, so anything still moving gets asked about each cycle.
  # Delivered parcels stop being polled -- there is nothing further to learn.
  defp poll_usps(source) do
    if RoomPackages.USPS.configured?(source) do
      pending =
        source.meta.tracking
        |> Enum.filter(fn t -> t.type == :usps and not delivered?(t) end)

      pending
      |> Enum.chunk_every(RoomPackages.USPS.max_batch())
      |> Enum.each(fn chunk ->
        numbers = Enum.map(chunk, & &1.number)

        case RoomPackages.USPS.track_many(source, numbers) do
          {:ok, summaries} ->
            # Re-read per write: update_source_meta_tracking/3 builds the new
            # list from the struct it is handed.
            Enum.reduce(summaries, source, fn summary, src ->
              existing = Enum.find(src.meta.tracking, &(&1.number == summary.number))

              if existing && changed?(existing, summary) do
                Configuration.update_source_meta_tracking(src, summary.number, summary)
                Configuration.get_source!(src.id)
              else
                src
              end
            end)

          {:error, reason} ->
            Logger.debug("USPS batch of #{length(numbers)}: #{inspect(reason)}")
        end
      end)
    end
  end

  defp delivered?(%{entries: entries}) when is_list(entries) do
    Enum.any?(entries, fn e -> Map.get(e, :delivered) == true or Map.get(e, "delivered") == true end)
  end

  defp delivered?(_), do: false

  # Only append when the status actually moved, otherwise every refresh would
  # add another identical entry and the history would be nothing but noise.
  defp changed?(%{entries: entries}, summary) when is_list(entries) do
    last = List.last(entries)
    last == nil or status_of(last) != summary.status
  end

  defp changed?(_, _), do: true

  defp status_of(entry), do: Map.get(entry, :status) || Map.get(entry, "status")

  def handle_call({:read, query}, _from, state) do
    {:reply, state.data, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

end
