defmodule RoomSanctum.Repo.Migrations.CreateRoutes do
  use Ecto.Migration

  def change do
    create table(:gtfs_routes) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :agency_id, :string
      add :route_id, :string
      add :route_short_name, :string
      add :route_long_name, :string
      add :route_desc, :string
      add :route_type, :string
      add :route_url, :string
      add :route_color, :string
      add :route_text_color, :string
      add :route_sort_order, :integer
      add :route_fare_class, :string
      add :line_id, :string
      add :listed_route, :string

      timestamps()
    end

    create unique_index(:gtfs_routes, [:source_id, :route_id])
  end
end
