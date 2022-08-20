defmodule RoomSanctum.Configuration.Queries.Weather do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :foci_id, :integer
    # has_one :foci, Foci, references: :foci_id
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(foci_id)a)
    |> validate_required([:foci_id])
  end
end
