defmodule RoomSanctum.Configuration.Queries.Pollen do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :foci_id, :integer
    field :days, :integer, default: 3
  end

  def changeset(source, params) do
    source
    |> cast(params, [:foci_id, :days])
    |> validate_required([:foci_id])
    |> validate_number(:days, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end
end
