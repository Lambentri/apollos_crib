defmodule RoomSanctum.Repo.Migrations.AddPlusToPythiae do
  use Ecto.Migration

  @moduledoc """
  Whether this Pythiae also publishes the Plus reading of its board.

  Plus keeps each arrival whole rather than flattening a route's departures
  into parallel lists of times, so it can say what the feed said about one
  departure -- how full, how late, which track. It goes to the Ankyra's
  `.plus` topic alongside the Basic board rather than in place of it: every
  client that reads the board today keeps reading exactly what it read before,
  and one that wants the longer answer subscribes to the other topic.

  Off by default, because it is a second publish of the same board on every
  tick and nothing should start paying for it without being asked.
  """

  def change do
    alter table(:cfg_pythiae) do
      add :plus, :boolean, default: false, null: false
    end
  end
end
