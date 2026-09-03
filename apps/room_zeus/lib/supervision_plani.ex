defmodule RoomZeus.PlaniSupervisor do
  @moduledoc """
  A worker per Plani, the same way visions get one.

  A Plani holds its own answers rather than reading a vision's, so it needs a
  process of its own to hold them in — and, unlike a vision, an anchor that
  has to be resolved before anything can be asked.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(instance_id) do
    spec = {RoomSanctum.Worker.Plani, [id: instance_id]}
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
    RoomSanctum.Configuration.list_plani()
    |> Enum.map(fn x ->
      RoomZeus.PlaniSupervisor.start_child(x.id |> Integer.to_string())
    end)
  end
end
