defmodule RoomZeus.AnkyraSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(instance_id) do
    spec = {RoomSanctum.Worker.Ankyra, [id: instance_id]}
    DynamicSupervisor.start_child(__MODULE__, spec)
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
    RoomSanctum.Accounts.list_users_rabbit()
    |> Enum.map(fn x ->
      RoomZeus.AnkyraSupervisor.start_child(x.id |> Integer.to_string())
    end)
  end
end
