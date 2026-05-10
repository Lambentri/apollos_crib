defmodule RoomSanctum.Configuration.Queries.Github do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :repo, :string
    field :owner, :string
    field :level, :string, default: "runs"
    field :status, :string
    field :conclusion, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, [:repo, :owner, :level, :status, :conclusion])
    |> validate_inclusion(:level, ["runs", "jobs"])
    |> validate_one_target()
  end

  defp validate_one_target(changeset) do
    repo = get_field(changeset, :repo)
    owner = get_field(changeset, :owner)

    case {repo, owner} do
      {nil, nil} -> add_error(changeset, :repo, "must specify either repo (owner/name) or owner")
      {"", ""} -> add_error(changeset, :repo, "must specify either repo (owner/name) or owner")
      _ -> changeset
    end
  end
end
