defmodule RoomSanctum.Repo.Migrations.NormaliseAirnowPoints do
  use Ecto.Migration

  @moduledoc """
  AirNow points were stored {lat, lon}, matching how foci used to be stored.
  Two transposed geometries compare correctly against each other, so "nearest
  station to this foci" worked -- until foci were normalised and the pair
  stopped agreeing, which put Boston's nearest monitor in Mozambique.

  The observations table is replaced wholesale every hour, so this only matters
  until the next refresh; the writer is fixed alongside. Migrating anyway so
  the data is right the moment this ships rather than an hour later.
  """

  def up do
    for {table, column} <- [
          {"airnow_hourly_observations", "point"},
          {"airnow_monitoring_sites", "point"}
        ] do
      execute("""
      UPDATE #{table}
      SET #{column} = ST_SetSRID(
            ST_MakePoint(ST_Y(#{column}::geometry), ST_X(#{column}::geometry)), 4326)
      WHERE #{column} IS NOT NULL
      """)
    end
  end

  def down do
    for {table, column} <- [
          {"airnow_hourly_observations", "point"},
          {"airnow_monitoring_sites", "point"}
        ] do
      execute("""
      UPDATE #{table}
      SET #{column} = ST_SetSRID(
            ST_MakePoint(ST_Y(#{column}::geometry), ST_X(#{column}::geometry)), 4326)
      WHERE #{column} IS NOT NULL
      """)
    end
  end
end
