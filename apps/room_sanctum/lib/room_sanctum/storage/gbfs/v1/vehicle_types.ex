defmodule RoomSanctum.Storage.GBFS.V1.VehicleTypes do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_vehicle_types" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :vehicle_type_id, :string
    field :form_factor, :string
    field :propulsion_type, :string
    field :max_range_meters, :float

    timestamps()
  end

  @doc """
  What to call this kind of vehicle.

  A feed identifies its vehicle types by an id of its own choosing -- Bay
  Wheels' e-bike is `"2"` -- so the id is never a name. What the feed does say
  about a type is its form factor and how it is propelled, which is exactly the
  distinction a rider cares about.
  """
  def label(%{form_factor: form_factor, propulsion_type: propulsion}),
    do: name_for(form_factor, propulsion)

  def label(_type), do: nil

  defp name_for(nil, _propulsion), do: nil
  # The combinations a rider has a word for. GBFS spells out the machine
  # ("bicycle", "electric_assist"); people say e-bike.
  defp name_for("bicycle", "human"), do: "Bike"
  defp name_for("bicycle", _electric), do: "E-bike"
  defp name_for("cargo_bicycle", "human"), do: "Cargo bike"
  defp name_for("cargo_bicycle", _electric), do: "Electric cargo bike"
  defp name_for("scooter" <> _, _propulsion), do: "Scooter"
  defp name_for("moped", _propulsion), do: "Moped"
  defp name_for("car", _propulsion), do: "Car"
  # Anything the spec adds later reads as well as its own words allow,
  # rather than not at all.
  defp name_for(factor, nil), do: humanise(factor)
  defp name_for(factor, "human"), do: humanise(factor)

  defp name_for(factor, propulsion),
    do: "#{humanise(propulsion)} #{String.downcase(humanise(factor))}"

  # "electric_assist" -> "Electric assist", "bicycle" -> "Bicycle".
  defp humanise(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @doc false
  def changeset(vehicle_types, attrs) do
    vehicle_types
    |> cast(attrs, [:vehicle_type_id, :form_factor, :propulsion_type, :max_range_meters])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:vehicle_type_id, :form_factor, :propulsion_type, :max_range_meters])
  end
end
