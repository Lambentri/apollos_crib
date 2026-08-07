defmodule RoomSanctum.Configuration.Queries.Cronos do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Two shapes of clock query.

    * `:modulo` -- the original "is now an even multiple of this period" check.
    * `:countdown` -- time until, or since, a fixed date, optionally recurring
      each year.

  `mode` defaults to `:modulo` so queries saved before countdown existed keep
  behaving exactly as they did.
  """

  embedded_schema do
    field :mode, Ecto.Enum, values: [:modulo, :countdown], default: :modulo

    # :modulo
    field :modulo, :integer
    field :offset, :integer
    field :period, Ecto.Enum, values: [:minute, :hour, :day, :week, :month]

    # :countdown -- naive because this is a wall-clock time at the Foci, so it
    # stays put across DST rather than drifting by an hour.
    field :target, :naive_datetime
    field :annual, :boolean, default: false

    # Both modes take their timezone from the Foci.
    field :foci_id, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(mode modulo offset period target annual foci_id)a)
    |> validate_required([:mode, :foci_id])
    |> validate_mode()
  end

  defp validate_mode(changeset) do
    case get_field(changeset, :mode) do
      :countdown -> validate_required(changeset, [:target])
      _ -> validate_required(changeset, [:modulo, :offset, :period])
    end
  end
end
