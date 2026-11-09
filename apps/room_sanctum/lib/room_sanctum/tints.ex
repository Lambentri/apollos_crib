defmodule RoomSanctum.Tints do
  @moduledoc ~S"""
  The colours a source, query or vision can be tinted with, and the optional
  label that subdivides one.

  Tint classes are built at runtime (`text-#{tint}-500`), so Tailwind cannot
  see them by scanning. The safelist in tailwind.config.js is what keeps them
  in the stylesheet, and it has to cover this list -- a colour offered here but
  missing there renders as an unstyled dot, which is how `red` behaved for
  sources.

  A tint is a colour and nothing else, which runs out once a colour means
  "everything about getting to work" and half of that is buses and half is
  bikes. The label is the subgroup: free text hung off a tint, so `sky` can
  hold `transit` and `weather` without either needing a colour of its own.
  Free rather than a fixed list because a tint already means whatever its
  owner decided it means, and so does a subgroup of one.
  """

  import Ecto.Changeset

  # Tailwind's full palette, warm to cool then neutrals, so the picker reads
  # as a spectrum rather than an alphabetical list.
  # Tailwind's palette minus `neutral`: daisyUI claims that name for a theme
  # colour, so it has no numbered scale and `bg-neutral-500` does not exist.
  # Offered as a tint it would render as an unstyled dot.
  @tints ~w(
    red orange amber yellow lime green emerald teal cyan sky blue indigo
    violet purple fuchsia pink rose slate gray zinc stone
  )

  # Long enough for a phrase, short enough to sit beside a dot in a list.
  @label_max 40

  def all, do: @tints

  def valid?(tint), do: tint in @tints

  def label_max_length, do: @label_max

  @doc """
  A label as it is stored: trimmed, and nil when nothing is left of it.

  Blank and nil are the same thing -- no subgroup -- because a form posts an
  empty string for a field nobody typed in.
  """
  def normalize_label(label) when is_binary(label) do
    case String.trim(label) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  def normalize_label(_), do: nil

  @doc """
  Whether a thing wearing `tint` and `label` is caught by a follow of
  `follow_tint` narrowed to `labels`.

  Narrowing to no labels is the whole tint, which is what every follow meant
  before labels existed and what one that names no subgroup still means.
  Narrowing to some is exactly those: a labelled follow does not pick up the
  unlabelled things wearing the colour, or the tint would be doing the
  narrowing no work.
  """
  def follows?(_tint, _label, blank, _labels) when blank in [nil, ""], do: false

  def follows?(tint, label, follow_tint, labels) do
    tint == follow_tint and label_among?(label, labels)
  end

  defp label_among?(_label, labels) when labels in [nil, []], do: true

  defp label_among?(label, labels) do
    case fold(label) do
      nil -> false
      key -> Enum.any?(labels, &(fold(&1) == key))
    end
  end

  @doc """
  Every distinct label worn under `tint`, given `{tint, label}` pairs -- what
  a picker offers as the subgroups that actually exist.

  Deduplicated case-insensitively, matching how `follows?/4` compares them, so
  `Transit` and `transit` are offered once and following either finds both.
  """
  def labels_in_use(pairs, tint) when is_list(pairs) do
    pairs
    |> Enum.filter(fn {t, _label} -> t == tint and t not in [nil, ""] end)
    |> Enum.map(fn {_t, label} -> normalize_label(label) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&fold/1)
    |> Enum.sort_by(&fold/1)
  end

  @doc """
  Normalise a single subgroup label on a changeset.

  A label subdivides a tint, so one with no tint under it labels nothing:
  clearing the colour clears the subgroup with it, which is what the pickers
  look like they do.
  """
  def put_label(changeset, tint_field \\ :tint, label_field \\ :tint_label) do
    label = changeset |> get_field(label_field) |> normalize_label()

    cond do
      get_field(changeset, tint_field) in [nil, ""] ->
        put_change(changeset, label_field, nil)

      is_nil(label) ->
        put_change(changeset, label_field, nil)

      String.length(label) > @label_max ->
        add_error(changeset, label_field, "is too long (maximum is #{@label_max} characters)")

      true ->
        put_change(changeset, label_field, label)
    end
  end

  @doc """
  Normalise a set of labels a follow is narrowed to -- the array counterpart
  of `put_label/3`, and clears itself the same way when the tint goes.
  """
  def put_labels(changeset, tint_field, labels_field) do
    if get_field(changeset, tint_field) in [nil, ""] do
      put_change(changeset, labels_field, [])
    else
      labels =
        changeset
        |> get_field(labels_field)
        |> List.wrap()
        |> Enum.map(&normalize_label/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(&fold/1)

      put_change(changeset, labels_field, labels)
    end
  end

  defp fold(label) do
    case normalize_label(label) do
      nil -> nil
      normalized -> String.downcase(normalized)
    end
  end
end
