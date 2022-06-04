defmodule RoomSanctum.Configuration.Queries.Calendar do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :filters, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(filters)a)
  end
end