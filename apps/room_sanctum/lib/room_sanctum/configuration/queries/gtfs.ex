defmodule RoomSanctum.Configuration.Queries.GTFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :stop, :string
    field :routes, {:array, :string}
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(stop routes)a)
    |> validate_required(:stop)
  end
end