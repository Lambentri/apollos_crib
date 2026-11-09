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

  alias RoomSanctum.Accounts.RabbitUser
  alias RoomSanctum.Configuration.{Foci, Ownership, Source}

  schema "cfg_plani" do
    field :name, :string
    belongs_to :user, RoomSanctum.Accounts.User

    # Where it is when it does not know where it is.
    #
    # More than one is allowed, because more than one is true: a house and an
    # office are both home, and which one answers depends on where you were
    # last. `home_foci_id` is the first of them and the answer for a Plani
    # that has never heard a position at all.
    field :home_foci_id, :integer
    field :home_foci_ids, {:array, :integer}, default: []
    field :home_tint, :string

    # Narrowed to these subgroups of it, or the whole tint when empty. A
    # colour of foci that has grown to mean two things -- the places you sleep
    # and the places you shop -- can be followed a corner at a time.
    field :home_tint_labels, {:array, :string}, default: []

    # How long a client may say nothing before the anchor goes home. Five
    # minutes suits a phone in a pocket on a bus; half an hour suits one that
    # only reports when it is opened.
    field :home_after_mins, :integer, default: 5

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

    # As with the homes: the subgroups of that tint to take, or all of them.
    field :follow_tint_labels, {:array, :string}, default: []
    field :radius, :integer, default: 800
    field :limit, :integer, default: 5

    # One entry per stop rather than one per source. A vision publishes an
    # entry per query and a query is one stop, so a client that draws a card
    # per entry needs to know nothing about grouping. Blended is fewer entries
    # and asks the client to render a list of its own.
    field :break_out, :boolean, default: false

    # Show a line only at the nearest stop it calls at. An areal query asks
    # every stop in the radius and a route calls at several, so without this
    # the same bus is listed once per stop.
    field :nearest_per_route, :boolean, default: false

    # How many bikes and docks one GBFS source may contribute. Nil is
    # everything inside the radius, which is what a dockless system in a city
    # centre answers with -- hundreds of them.
    field :bike_limit, :integer

    timestamps()
  end

  @doc false
  def changeset(plani, attrs) do
    plani
    |> cast(attrs, [
      :name,
      :user_id,
      :home_foci_id,
      :home_foci_ids,
      :home_tint,
      :home_tint_labels,
      :home_after_mins,
      :ankyra_id,
      :client_id,
      :sources,
      :follow_tint,
      :follow_tint_labels,
      :radius,
      :limit,
      :break_out,
      :nearest_per_route,
      :bike_limit
    ])
    |> validate_required([:name, :home_foci_id])
    # The same bounds an area query keeps, and for the same reason: past a
    # couple of kilometres this stops meaning "near me".
    |> validate_number(:radius, greater_than_or_equal_to: 50, less_than_or_equal_to: 3000)
    |> validate_number(:limit, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    # Looser than `limit`: loose bikes are counted rather than read one by one,
    # so a larger number is still a sensible thing to ask for.
    |> validate_number(:bike_limit, greater_than_or_equal_to: 1, less_than_or_equal_to: 50)
    # Offered as a menu of five minute steps, so the number is never anything
    # but one of these -- but a form is not the only way in.
    |> validate_inclusion(:home_after_mins, [5, 10, 15, 20, 25, 30])
    |> validate_tint()
    |> validate_home_tint()
    |> RoomSanctum.Tints.put_labels(:follow_tint, :follow_tint_labels)
    |> RoomSanctum.Tints.put_labels(:home_tint, :home_tint_labels)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:home_foci_id)
    # The form only offers the owner's own. Anything else would ask another
    # user's sources, follow their client's position, or call their foci home.
    |> Ownership.validate_owned(:home_foci_id, Foci)
    |> Ownership.validate_owned(:home_foci_ids, Foci)
    |> Ownership.validate_owned(:ankyra_id, RabbitUser)
    |> Ownership.validate_owned(:sources, Source)
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

  defp validate_home_tint(changeset) do
    validate_change(changeset, :home_tint, fn :home_tint, tint ->
      if tint in [nil, ""] or RoomSanctum.Tints.valid?(tint),
        do: [],
        else: [home_tint: "is not a tint"]
    end)
  end

  @doc """
  Every foci this Plani calls home: the first one, any others it names, and
  any wearing its home tint -- narrowed, if it names any, to the subgroups of
  that tint it follows.

  In that order and deduplicated, so `home_foci_id` stays the one a Plani with
  no position falls back to -- which is what it has always been, and what
  keeps every existing Plani behaving exactly as it did.
  """
  def homes_for(%__MODULE__{} = plani, all_foci) do
    tinted =
      all_foci
      |> Enum.filter(&follows_home?(plani, &1))
      |> Enum.map(& &1.id)

    ([plani.home_foci_id] ++ (plani.home_foci_ids || []) ++ tinted)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Every source this Plani asks: the ones it names, and the ones wearing its
  tint -- narrowed, if it names any, to the subgroups of that tint it
  follows.

  A union rather than a choice, so following a tint can be a shortcut to most
  of a list with one or two named on top of it.
  """
  def sources_for(%__MODULE__{} = plani, all_sources) do
    tinted =
      all_sources
      |> Enum.filter(&follows_source?(plani, &1))
      |> Enum.map(& &1.id)

    (plani.sources ++ tinted) |> Enum.uniq()
  end

  defp follows_home?(plani, foci) do
    RoomSanctum.Tints.follows?(
      foci.tint,
      Map.get(foci, :tint_label),
      plani.home_tint,
      plani.home_tint_labels
    )
  end

  defp follows_source?(plani, source) do
    RoomSanctum.Tints.follows?(
      tint_of(source),
      label_of(source),
      plani.follow_tint,
      plani.follow_tint_labels
    )
  end

  defp tint_of(source), do: source.meta && Map.get(source.meta, :tint)
  defp label_of(source), do: source.meta && Map.get(source.meta, :tint_label)
end
