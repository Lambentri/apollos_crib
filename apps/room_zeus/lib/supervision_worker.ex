defmodule RoomZeus.DynSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # The worker behind each source type; a type not listed starts nothing.
  @workers %{
    gtfs: RoomGtfs.Worker,
    gbfs: RoomGbfs.Worker,
    aqi: RoomAirQuality.Worker,
    tidal: RoomTidal.Worker,
    weather: RoomWeather.Worker,
    calendar: RoomCalendar.Worker,
    gitlab: RoomGitlab.Worker,
    github: RoomGithub.Worker,
    packages: RoomPackages.Worker,
    drought: RoomDrought.Worker,
    pollen: RoomPollen.Worker,
    icarus: RoomIcarus.Worker,
    mailbox: RoomHermes.Mail.ImapWorker,
    treasury: RoomTreasury.Worker,
    bourse: RoomBourse.Worker
  }

  def start_child(type, instance_id) do
    case Map.fetch(@workers, type) do
      {:ok, worker} -> DynamicSupervisor.start_child(__MODULE__, {worker, [name: instance_id]})
      :error -> nil
    end
  end

  @impl true
  def init(_init_arg) do
    Periodic.start_link(
      every: :timer.seconds(10),
      run: &do_children/0,
      initial_delay: 1000
    )

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp do_children do
    RoomSanctum.Configuration.list_cfg_sources()
    |> Enum.map(fn x ->
      RoomZeus.DynSupervisor.start_child(x.type, x.id |> Integer.to_string())
    end)
  end
end
