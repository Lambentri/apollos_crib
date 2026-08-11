defmodule RoomSanctum.Tints do
  @moduledoc ~S"""
  The colours a source, query or vision can be tinted with.

  Tint classes are built at runtime (`text-#{tint}-500`), so Tailwind cannot
  see them by scanning. The safelist in tailwind.config.js is what keeps them
  in the stylesheet, and it has to cover this list -- a colour offered here but
  missing there renders as an unstyled dot, which is how `red` behaved for
  sources.
  """

  # Tailwind's full palette, warm to cool then neutrals, so the picker reads
  # as a spectrum rather than an alphabetical list.
  # Tailwind's palette minus `neutral`: daisyUI claims that name for a theme
  # colour, so it has no numbered scale and `bg-neutral-500` does not exist.
  # Offered as a tint it would render as an unstyled dot.
  @tints ~w(
    red orange amber yellow lime green emerald teal cyan sky blue indigo
    violet purple fuchsia pink rose slate gray zinc stone
  )

  def all, do: @tints

  def valid?(tint), do: tint in @tints
end
