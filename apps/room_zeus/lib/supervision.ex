defmodule RoomZeus.DynSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(type, instance_id) do
    spec = case type do
      :gtfs -> {RoomGtfs.Worker, [name: instance_id]}
      :gbfs -> {RoomGbfs.Worker, [name: instance_id]}
      :aqi -> {RoomAirQuality.Worker, [name: instance_id]}
      _ -> nil
    end
    if spec != nil do
      DynamicSupervisor.start_child(__MODULE__, spec)
    end

  end


  @impl true
  def init(init_arg) do
    Periodic.start_link(
      every: :timer.seconds(10),
      run: &do_children/0,
      initial_delay: 1000
    )
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp do_children do
      RoomSanctum.Configuration.list_cfg_sources()
      |> Enum.map(fn x -> RoomZeus.DynSupervisor.start_child(x.type, x.id |> Integer.to_string) end)
  end
end