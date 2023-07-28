defmodule RoomSanctum.Repo.Migrations.RouteDescEmbiggen do
  use Ecto.Migration

  def change do
    execute """
            ALTER TABLE gtfs_routes
              DROP COLUMN searchable;
    """

    execute """
    alter table gtfs_routes
        alter column route_desc type varchar(1024) using route_desc::varchar(1024);
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
  end
end
