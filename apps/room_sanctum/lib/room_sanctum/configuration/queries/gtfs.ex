defmodule RoomSanctum.Configuration.Queries.GTFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  # Metres. Transit stops are further apart than bike docks and people walk to
  # them, so this starts wider than the GBFS default.
  @default_radius 800
  @default_stops 3

  embedded_schema do
    # :station names one stop. :area asks what is leaving near a foci, which
    # is what a foci that moves is for.
    field :mode, Ecto.Enum, values: [:station, :area], default: :station

    # :station
    field :stop, :string
    field :routes, {:array, :string}

    # :area
    field :foci_id, :integer
    field :radius, :integer, default: @default_radius
    # How many stops to gather from. A board is a dozen departures; asking
    # twenty stops for them would fill it with the same bus from every corner.
    field :stops, :integer, default: @default_stops
  end

  def default_radius, do: @default_radius
  def default_stops, do: @default_stops

  def changeset(source, params) do
    source
    |> cast(params, ~w(mode stop routes foci_id radius stops)a)
    |> validate_required([:mode])
    |> validate_mode()
  end

  defp validate_mode(changeset) do
    case get_field(changeset, :mode) do
      :area -> validate_area(changeset)
      _ -> validate_station(changeset)
    end
  end

  defp validate_station(changeset), do: validate_required(changeset, :stop)

  defp validate_area(changeset) do
    changeset
    |> validate_required([:foci_id, :radius])
    # Beyond a couple of kilometres this stops being "what can I catch from
    # here" and starts being every stop in the city.
    |> validate_number(:radius, greater_than_or_equal_to: 50, less_than_or_equal_to: 3000)
    |> validate_number(:stops, greater_than_or_equal_to: 1, less_than_or_equal_to: 8)
  end
end
