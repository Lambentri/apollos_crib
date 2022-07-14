defmodule RoomSanctum.Configuration.Queries.Tidal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :station_id, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(station_id)a)
    |> validate_required([:station_id])
  end
end
