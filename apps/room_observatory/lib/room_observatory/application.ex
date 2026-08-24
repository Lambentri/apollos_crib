defmodule RoomObservatory.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # PromEx is the whole application. It starts its own metrics server on
    # 9568 (see config/config.exs), so there is nothing else to supervise.
    #
    # Both Phoenix endpoints are already running by the time this starts —
    # room_sanctum and room_hermes come earlier in the release's application
    # list, because this app depends on both. That ordering does not matter for
    # correctness: PromEx attaches :telemetry handlers, and a handler attached
    # after an endpoint has started still receives every subsequent request.
    children = [RoomObservatory.PromEx]

    Supervisor.start_link(children, strategy: :one_for_one, name: RoomObservatory.Supervisor)
  end
end
