defmodule RoomSanctum.Configuration.Queries.Calendar do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :filters, :string
    field :days, :integer
    field :limit, :integer
    field :foci_id, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(filters days limit foci_id)a)
    |> validate_required([:days, :limit, :foci_id])
  end
end
