defmodule RoomGtfs.DynSupervisor do
  # Automatically defines child_spec/1
  use DynamicSupervisor



  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(instance_id) do
    # If MyWorker is not using the new child specs, we need to pass a map:
    # spec = %{id: MyWorker, start: {MyWorker, :start_link, [foo, bar, baz]}}
    spec = {RoomGtfs.Worker, [name: instance_id]}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end


  @impl true
  def init(_init_arg) do
    Periodic.start_link(
      every: :timer.seconds(15),
      run: &do_children/0,
      initial_delay: 3000
    )
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp do_children do
    RoomSanctum.Configuration.list_cfg_sources(:gtfs)
    |> Enum.map(fn x -> start_child(x.id) end)
  end
end