defmodule RoomSanctum.Configuration.Queries.Ephem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :foci_id, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, [:foci_id])
    |> validate_required([:foci_id])
  end
end