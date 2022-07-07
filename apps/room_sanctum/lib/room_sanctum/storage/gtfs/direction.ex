defmodule RoomSanctum.Storage.GTFS.Direction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_directions" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :direction, :string
    field :direction_id, :integer
    field :route_id, :string

    timestamps()
  end

  @doc false
  def changeset(direction, attrs) do
    direction
    |> cast(attrs, [:route_id, :direction_id, :direction, :source_id])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:route_id, :direction_id, :direction])
  end
end
