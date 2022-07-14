defmodule RoomSanctum.Storage.GTFS.Route do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_routes" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :agency_id, :string
    field :line_id, :string
    field :listed_route, :string
    field :route_color, :string
    field :route_desc, :string
    field :route_fare_class, :string
    field :route_id, :string
    field :route_long_name, :string
    field :route_short_name, :string
    field :route_sort_order, :integer
    field :route_text_color, :string
    field :route_type, :string
    field :route_url, :string

    timestamps()
  end

  @doc false
  def changeset(route, attrs) do
    route
    |> cast(attrs, [
      :agency_id,
      :route_id,
      :route_short_name,
      :route_long_name,
      :route_desc,
      :route_type,
      :route_url,
      :route_color,
      :route_text_color,
      :route_sort_order,
      :route_fare_class,
      :line_id,
      :listed_route,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :agency_id,
      :route_id,
      :route_desc,
      :route_type,
      :route_color,
      :route_text_color,
      :route_sort_order,
      :route_fare_class,
      :line_id
    ])
  end
end
