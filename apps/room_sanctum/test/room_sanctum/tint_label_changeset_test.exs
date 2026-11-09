defmodule RoomSanctum.TintLabelChangesetTest do
  @moduledoc """
  How a subgroup label lands in a changeset, on the one schema that keeps its
  tint in a column. Sources, queries and visions run the same rule through
  `RoomSanctum.Tints.put_label/3` on their meta embeds.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration.Foci

  defp place, do: %Geo.Point{coordinates: {-71.06, 42.36}, srid: 4326}

  defp label(attrs) do
    %Foci{}
    |> Foci.changeset(Map.merge(%{name: "Home", place: place(), tint: "sky"}, attrs))
    |> Ecto.Changeset.apply_changes()
    |> Map.get(:tint_label)
  end

  test "a label is stored trimmed" do
    assert label(%{tint_label: "  transit  "}) == "transit"
  end

  test "a blank label is no label" do
    assert label(%{tint_label: ""}) == nil
    assert label(%{tint_label: "   "}) == nil
  end

  test "a label with no tint under it labels nothing" do
    # Clearing the colour clears the subgroup, which is what the picker looks
    # like it does -- the label input only appears once a tint is chosen.
    assert label(%{tint: nil, tint_label: "transit"}) == nil
    assert label(%{tint: "", tint_label: "transit"}) == nil
  end

  test "an overlong label is refused rather than truncated" do
    too_long = String.duplicate("a", RoomSanctum.Tints.label_max_length() + 1)

    changeset =
      Foci.changeset(%Foci{}, %{
        name: "Home",
        place: place(),
        tint: "sky",
        tint_label: too_long
      })

    refute changeset.valid?
    assert {"is too long (maximum is 40 characters)", _} = changeset.errors[:tint_label]
  end

  test "a foci with a tint and no label is exactly what it always was" do
    assert label(%{}) == nil
  end
end
