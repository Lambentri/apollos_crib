defmodule RoomSanctum.Repo.Migrations.CreateIcarusFlightWatches do
  use Ecto.Migration

  def change do
    create table(:icarus_flight_watches) do
      # Identity is the flight instance, not the query that asked for it, so two
      # people watching the same arrival share one watch and one poll budget.
      #
      # The callsign is what ADS-B actually transmits (UAL558), resolved from the
      # IATA flight number on the ticket.
      add :callsign, :string, null: false
      add :dest, :string, null: false
      add :sched_arrival, :utc_datetime, null: false

      # pending -> enroute -> landed, plus expired when the window closes with
      # no sighting. Kept as a string so adding a state needs no migration.
      add :state, :string, null: false, default: "pending"

      # Latched on first sighting: the airframe's immutable ICAO address. Once
      # set, tracking follows this rather than the callsign, so a later instance
      # of the same flight number cannot be confused for this one.
      add :hex, :string

      add :registration, :string
      add :aircraft_type, :string

      add :first_seen_at, :utc_datetime
      add :last_seen_at, :utc_datetime
      add :landed_at, :utc_datetime

      # Most recent computed estimate, so the UI has something to show between
      # polls and after the aircraft drops out of coverage.
      add :eta, :utc_datetime
      add :last_position, :map
      add :last_polled_at, :utc_datetime

      timestamps()
    end

    create unique_index(:icarus_flight_watches, [:callsign, :dest, :sched_arrival])
    create index(:icarus_flight_watches, [:state])
    create index(:icarus_flight_watches, [:hex])
  end
end
