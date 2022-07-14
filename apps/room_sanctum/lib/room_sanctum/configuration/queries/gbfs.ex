defmodule RoomSanctum.Configuration.Queries.GBFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :stop_id, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(stop_id)a)
    |> validate_required(:stop_id)
  end
end
