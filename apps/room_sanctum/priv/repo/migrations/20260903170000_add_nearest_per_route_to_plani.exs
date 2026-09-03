defmodule RoomSanctum.Repo.Migrations.AddNearestPerRouteToPlani do
  use Ecto.Migration

  @moduledoc """
  Whether a line is shown only at the nearest stop it calls at.

  An areal query asks every stop inside the radius, and a bus route calls at
  several of them -- so the same departure appears once per stop. Nobody walks
  to the second-nearest stop to catch a bus that is also stopping at the first.
  """

  def change do
    alter table(:cfg_plani) do
      add :nearest_per_route, :boolean, default: false, null: false
    end
  end
end
