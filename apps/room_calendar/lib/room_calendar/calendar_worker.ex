defmodule RoomCalendar.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage
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

  def handle_cast(:update_static, state) do
    Logger.info("iCAL::#{state.id} updating")
    dt = NaiveDateTime.local_now()
    cfg = Configuration.get_source!(state.id)
    url = cfg.config.url |> String.replace("webcal://", "http://")

    case HTTPoison.get(url) do
      {:ok, result} ->
        entries = ICalendar.from_ics(result.body)

        data =
          entries
          |> Enum.map(fn x -> %{blob: x |> Map.from_struct(), source_id: state.id |> intify, date_start: x.dtstart, date_end: x.dtend} end)
          |> Enum.map(fn x ->
            RoomSanctum.Storage.change_icalendar(%RoomSanctum.Storage.ICalendar{}, x).changes
            |> Map.put(:inserted_at, dt)
            |> Map.put(:updated_at, dt)
          end)

        Repo.insert_all(
          RoomSanctum.Storage.ICalendar,
          data,
          on_conflict: {:replace_all_except, [:id]},
          conflict_target: [:source_id, :blob]
        )
        |> IO.inspect()

      {:error, reason} ->
        IO.puts("error #{reason.reason}")
    end

    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
