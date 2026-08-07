defmodule RoomSanctum.Storage.Icarus.FlightWatch do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Durable state for one tracked flight instance.

  A watch outlives the worker: it spans hours, must survive a restart, and its
  whole point is remembering which airframe was latched so a later instance of
  the same flight number is never mistaken for this one.

  Keyed on the flight instance rather than on a query, so several queries
  watching the same arrival share one watch.
  """

  @states ~w(pending enroute landed expired)

  def states, do: @states

  schema "icarus_flight_watches" do
    field :callsign, :string
    field :dest, :string
    field :sched_arrival, :utc_datetime

    field :state, :string, default: "pending"

    field :hex, :string
    field :registration, :string
    field :aircraft_type, :string

    field :first_seen_at, :utc_datetime
    field :last_seen_at, :utc_datetime
    field :landed_at, :utc_datetime

    field :eta, :utc_datetime
    field :last_position, :map
    field :last_polled_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(watch, attrs) do
    watch
    |> cast(attrs, [
      :callsign,
      :dest,
      :sched_arrival,
      :state,
      :hex,
      :registration,
      :aircraft_type,
      :first_seen_at,
      :last_seen_at,
      :landed_at,
      :eta,
      :last_position,
      :last_polled_at
    ])
    |> validate_required([:callsign, :dest, :sched_arrival, :state])
    |> validate_inclusion(:state, @states)
    |> unique_constraint([:callsign, :dest, :sched_arrival])
  end
end
