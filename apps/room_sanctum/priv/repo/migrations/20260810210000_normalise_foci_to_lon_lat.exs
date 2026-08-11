defmodule RoomSanctum.Repo.Migrations.NormaliseFociToLonLat do
  use Ecto.Migration

  @moduledoc """
  Foci were stored {lat, lon}, the reverse of every other geometry in this
  database -- gbfs stations and free bikes are {lon, lat}, as PostGIS and
  GeoJSON expect.

  That inconsistency was load-bearing: every reader compensated for it, and the
  one place that did not -- ordering hourly observations by st_distance against
  a foci -- was silently comparing a point against its own transpose.

  Swapping the stored values and the code that reads them has to happen
  together, so this migration ships with that change.
  """

  def up do
    execute("""
    UPDATE cfg_focis
    SET place = ST_SetSRID(ST_MakePoint(ST_Y(place::geometry), ST_X(place::geometry)), 4326)
    WHERE place IS NOT NULL
    """)
  end

  def down do
    execute("""
    UPDATE cfg_focis
    SET place = ST_SetSRID(ST_MakePoint(ST_Y(place::geometry), ST_X(place::geometry)), 4326)
    WHERE place IS NOT NULL
    """)
  end
end
