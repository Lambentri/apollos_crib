defmodule RoomSanctum.Configuration.Foci do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_focis" do
    field :name, :string
    field :place, Geo.PostGIS.Geometry

    # As on a source: a colour that says these belong together, without making
    # a group out of it. A Plani can follow a tint of foci as its homes.
    field :tint, :string
    belongs_to :user, RoomSanctum.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(foci, attrs) do
    foci
    |> cast(attrs, [:name, :place, :user_id, :tint])
    |> foreign_key_constraint(:user_id)
    |> validate_required([:name, :place])
    |> validate_tint()
  end

  # An unknown tint renders as an unstyled dot rather than failing, which is
  # the kind of wrong that goes unnoticed. Same rule as a Plani's follow_tint.
  defp validate_tint(changeset) do
    validate_change(changeset, :tint, fn :tint, tint ->
      if tint in [nil, ""] or RoomSanctum.Tints.valid?(tint), do: [], else: [tint: "is not a tint"]
    end)
  end
end
