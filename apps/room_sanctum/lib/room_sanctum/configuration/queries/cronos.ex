defmodule RoomSanctum.Configuration.Queries.Cronos do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  # TODO possibly do a poly embed here for diff types of periods

  embedded_schema do
    field :modulo, :integer
    field :offset, :integer
    field :period, Ecto.Enum, values: [:minute, :hour, :day, :week, :month]

    field :foci_id, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(modulo offset period foci_id)a)
    |> validate_required([:modulo, :offset, :period, :foci_id])
  end
end
