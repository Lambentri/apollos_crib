defmodule RoomSanctum.Configuration.Configs.Github do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :api_url, :string, default: "https://api.github.com"
    field :pat, :string
    field :repos, {:array, :string}, default: []
    field :owners, {:array, :string}, default: []
    field :poll_seconds, :integer, default: 60
  end

  def changeset(source, params) do
    source
    |> cast(params, [:api_url, :pat, :repos, :owners, :poll_seconds])
    |> validate_required([:api_url, :pat])
    |> validate_number(:poll_seconds, greater_than_or_equal_to: 15, less_than_or_equal_to: 3600)
  end
end
