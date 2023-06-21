defmodule RoomSanctum.Repo.Migrations.StorageFts do
  use Ecto.Migration

  def change do
    execute """
    ALTER TABLE gtfs_stops
      ADD COLUMN searchable TSVECTOR
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(stop_name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(stop_desc, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(stop_code, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(stop_id, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(platform_code, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(platform_name, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(stop_address, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(stop_url, '')), 'C')
      ) STORED;
    """

    execute """
    CREATE INDEX gtfs_stops_searchable_idx ON gtfs_stops USING gin(searchable);
    """

    execute """
    ALTER TABLE gtfs_routes
      ADD COLUMN searchable tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(route_short_name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(route_long_name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(route_desc, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(route_type, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(route_url, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(listed_route, '')), 'C')
      ) STORED;
    """

    execute """
    CREATE INDEX gtfs_routes_searchable_idx ON gtfs_routes USING gin(searchable);
    """

    execute """
    ALTER TABLE gbfs_station_information
      ADD COLUMN searchable tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(short_name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(legacy_id, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(external_id, '')), 'B')
      ) STORED;
    """

      execute """
    CREATE INDEX gbfs_station_information_searchable_idx ON gbfs_station_information USING gin(searchable);
    """
  end
end
