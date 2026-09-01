defmodule RoomSanctum.Configuration.Queries.GBFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Two shapes of bike query share one embed, the way an icarus query does,
  because Keryx and the LiveViews dispatch on the *source* type rather than the
  query type.

    * `:station` -- one dock. What is available where it is bolted down.
    * `:area` -- every free-floating bike within a radius of a Foci, and
      optionally the docks in it too. A dockless system has nothing to name, so
      a station id cannot ask the question at all.

  `:station` is the default so every query saved before area mode existed keeps
  meaning what it meant.
  """

  @default_radius 500

  embedded_schema do
    field :mode, Ecto.Enum, values: [:station, :area], default: :station

    # :station
    field :stop_id, :string

    # :area. Metres, because that is what the query is measured in against a
    # geography and what a person picking a radius on a city map is thinking
    # in; 500 is a few minutes' walk.
    field :foci_id, :integer
    field :radius, :integer, default: @default_radius
    # Off by default: a dockless system has no docks to return, and on a system
    # that has both this doubles what the query answers with.
    field :include_docks, :boolean, default: false
  end

  def default_radius, do: @default_radius

  def changeset(source, params) do
    source
    |> cast(params, ~w(mode stop_id foci_id radius include_docks)a)
    |> validate_required([:mode])
    |> validate_mode()
  end

  defp validate_mode(changeset) do
    case get_field(changeset, :mode) do
      :area -> validate_area(changeset)
      _ -> validate_station(changeset)
    end
  end

  defp validate_station(changeset), do: validate_required(changeset, :stop_id)

  defp validate_area(changeset) do
    changeset
    |> validate_required([:foci_id, :radius])
    # Above a few kilometres this stops being "bikes near me" and starts being
    # every bike in the city, which is a map with thousands of markers on it.
    |> validate_number(:radius, greater_than_or_equal_to: 50, less_than_or_equal_to: 5000)
  end
end
