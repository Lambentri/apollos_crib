defmodule RoomSanctum.Repo.Migrations.AddBreakOutToPlani do
  use Ecto.Migration

  @moduledoc """
  Whether a Plani publishes one entry per source or one per stop.

  A vision publishes an entry per query, and a query is one stop -- so a client
  draws a card per stop and needs to know nothing about grouping. A Plani
  blends its sources into one entry each, which is fewer entries but asks the
  client to render a list. Broken out, a Plani looks exactly like a vision on
  the wire, and the clients stay as simple as they are.
  """

  def change do
    alter table(:cfg_plani) do
      add :break_out, :boolean, default: false, null: false
    end
  end
end
