defmodule RoomSanctum.Configuration.Queries.Gitlab do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :statuses, :string
    field :projects, {:array, :integer}
#    field :since, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(statuses projects)a)
    |> validate_required([:statuses])
  end
end
