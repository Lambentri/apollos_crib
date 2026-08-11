defmodule RoomSanctum.TintsTest do
  @moduledoc """
  Tint classes are assembled at runtime, so Tailwind never sees them in the
  source. The safelist in tailwind.config.js is the only thing keeping them in
  the stylesheet -- a colour offered here but missing there renders as an
  unstyled dot, which is exactly how `red` behaved for sources.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Tints

  @css Path.expand("../../priv/static/assets/app.css", __DIR__)

  # Every shape a tint is used in across the templates.
  @patterns [
    "bg-~s-500",
    "bg-~s-100",
    "bg-~s-50",
    "text-~s-500",
    "text-~s-600",
    "text-~s-700",
    "text-~s-800",
    "border-~s-200",
    "border-~s-300",
    "ring-~s-500"
  ]

  test "the palette is not empty and holds no duplicates" do
    assert length(Tints.all()) > 10
    assert Tints.all() == Enum.uniq(Tints.all())
  end

  test "daisyui's own colour names are not offered" do
    # these have no numbered scale, so bg-neutral-500 does not exist
    reserved = ~w(primary secondary accent neutral info success warning error base)

    assert Tints.all() -- reserved == Tints.all()
  end

  test "valid?/1 accepts the palette and nothing else" do
    for tint <- Tints.all(), do: assert(Tints.valid?(tint), tint)

    refute Tints.valid?("neutral")
    refute Tints.valid?("chartreuse")
    refute Tints.valid?("")
    refute Tints.valid?(nil)
  end

  @tag :stylesheet
  test "every offered tint has its classes in the built stylesheet" do
    case File.read(@css) do
      {:ok, css} ->
        missing =
          for tint <- Tints.all(),
              pattern <- @patterns,
              class = :io_lib.format(pattern, [tint]) |> to_string(),
              not String.contains?(css, "." <> class),
              do: class

        assert missing == [],
               """
               These tint classes are offered but not in the stylesheet, so
               they would render unstyled. Check the safelist in
               assets/tailwind.config.js:

                 #{Enum.join(missing, "\n  ")}
               """

      {:error, _} ->
        # assets have not been built in this checkout; nothing to check
        :ok
    end
  end
end
