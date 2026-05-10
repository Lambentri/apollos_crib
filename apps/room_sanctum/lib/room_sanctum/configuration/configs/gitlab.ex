defmodule RoomSanctum.Configuration.Configs.Gitlab do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
    field :pat, :string
    field :projects, {:array, :string}, default: []
    field :namespaces, {:array, :string}, default: []
    field :poll_seconds, :integer, default: 10
  end

  def changeset(source, params) do
    source
    |> cast(params, [:url, :pat, :projects, :namespaces, :poll_seconds])
    |> validate_required([:url, :pat])
    |> validate_number(:poll_seconds, greater_than_or_equal_to: 5, less_than_or_equal_to: 3600)
  end
end
