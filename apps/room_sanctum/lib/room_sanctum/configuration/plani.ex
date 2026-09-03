defmodule RoomSanctum.Configuration.Plani do
  @moduledoc """
  A vision whose anchor moves.

  Where a Vision is a list of queries asked in the places they name, a Plani is
  a list of *sources* asked around wherever its client currently is. It is a
  sibling of a vision, not a mode on one: a Pythiae shows one or the other.

  The position itself is never stored. It lives in the Plani's worker and
  expires there; `home_foci` is what answers when nothing has reported
  recently, which is also what a Plani that has never heard from anybody
  falls back to.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_plani" do
    field :name, :string
    belongs_to :user, RoomSanctum.Accounts.User

    # Where it is when it does not know where it is.
    field :home_foci_id, :integer

    # Whose position to follow. An Ankyra may carry several clients and only
    # one of them is the one that travels.
    field :ankyra_id, :integer
    field :client_id, :string

    # What to look for around the anchor.
    field :sources, {:array, :integer}, default: []

    # Instead of, or as well as, naming them: every source carrying this tint.
    # A source tinted later joins without the Plani being edited, which is
    # what makes this a shortcut rather than a bulk select.
    field :follow_tint, :string
    field :radius, :integer, default: 800
    field :limit, :integer, default: 5

    timestamps()
  end

  @doc false
  def changeset(plani, attrs) do
    plani
    |> cast(attrs, [
      :name,
      :user_id,
      :home_foci_id,
      :ankyra_id,
      :client_id,
      :sources,
      :follow_tint,
      :radius,
      :limit
    ])
    |> validate_required([:name, :home_foci_id])
    # The same bounds an area query keeps, and for the same reason: past a
    # couple of kilometres this stops meaning "near me".
    |> validate_number(:radius, greater_than_or_equal_to: 50, less_than_or_equal_to: 3000)
    |> validate_number(:limit, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    |> validate_tint()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:home_foci_id)
  end

  # A tint that is not one of the offered colours renders as an unstyled dot
  # rather than failing, which is the kind of wrong that goes unnoticed.
  defp validate_tint(changeset) do
    validate_change(changeset, :follow_tint, fn :follow_tint, tint ->
      if tint in [nil, ""] or RoomSanctum.Tints.valid?(tint) do
        []
      else
        [follow_tint: "is not a tint"]
      end
    end)
  end

  @doc """
  Every source this Plani asks: the ones it names, and the ones wearing its
  tint.

  A union rather than a choice, so following a tint can be a shortcut to most
  of a list with one or two named on top of it.
  """
  def sources_for(%__MODULE__{} = plani, all_sources) do
    tinted =
      case plani.follow_tint do
        nil -> []
        "" -> []
        tint -> all_sources |> Enum.filter(&(tint_of(&1) == tint)) |> Enum.map(& &1.id)
      end

    (plani.sources ++ tinted) |> Enum.uniq()
  end

  defp tint_of(source), do: source.meta && Map.get(source.meta, :tint)
end
