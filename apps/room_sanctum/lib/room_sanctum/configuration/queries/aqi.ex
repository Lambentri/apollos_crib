defmodule RoomSanctum.Configuration.Queries.AQI do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :location_zip, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(location_zip)a)
    |> validate_required(:location_zip)
  end
end