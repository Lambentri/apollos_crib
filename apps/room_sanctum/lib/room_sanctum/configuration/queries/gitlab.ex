defmodule RoomSanctum.Configuration.Queries.Gitlab do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :namespace, :string
    field :statuses, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(id namespace statuses)a)
    |> validate_one_target()
  end

  defp validate_one_target(changeset) do
    id = get_field(changeset, :id)
    ns = get_field(changeset, :namespace)

    case {id, ns} do
      {nil, nil} ->
        add_error(changeset, :namespace, "must specify either project id or namespace")

      _ ->
        changeset
    end
  end
end
