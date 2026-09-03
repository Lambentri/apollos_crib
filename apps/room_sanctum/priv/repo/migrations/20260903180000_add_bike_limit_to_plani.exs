defmodule RoomSanctum.Repo.Migrations.AddBikeLimitToPlani do
  use Ecto.Migration

  @moduledoc """
  How many bikes and docks a GBFS source may contribute.

  Stops and air quality monitors were always bounded by the Plani's `limit`;
  bikes and docks were bounded only by the radius, so a dockless system in a
  city centre could answer with hundreds. Null keeps that -- everything inside
  the radius -- since that is what existing Plani have been doing.
  """

  def change do
    alter table(:cfg_plani) do
      add :bike_limit, :integer
    end
  end
end
