defmodule RoomSanctum.Storage.GTFS.Shape do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  A point on a route's drawn path, from shapes.txt.

  Trips reference these by shape_id, which is what makes a route line follow
  the road rather than hopping stop to stop.
  """

  schema "gtfs_shapes" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :shape_id, :string
    field :shape_pt_lat, :float
    field :shape_pt_lon, :float
    field :shape_pt_sequence, :integer
    field :shape_dist_traveled, :float

    timestamps()
  end

  @doc false
  def changeset(shape, attrs) do
    shape
    |> cast(attrs, [
      :shape_id,
      :shape_pt_lat,
      :shape_pt_lon,
      :shape_pt_sequence,
      :shape_dist_traveled,
      :source_id
    ])
    |> validate_required([:shape_id, :source_id])
  end
end
