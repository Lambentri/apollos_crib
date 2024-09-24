defmodule RoomSanctum.Configuration.Queries.Packages do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :show_delivered_for, :integer, default: 2
    field :carriers, {:array, Ecto.Enum}, values: [:ups, :fedex, :usps, :uniuni]
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(show_delivered_for carriers)a)
    |> validate_required([:show_delivered_for])
  end
end
