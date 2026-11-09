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

  describe "subgroup labels" do
    test "a label is stored trimmed, and blank is no label at all" do
      assert Tints.normalize_label("  transit ") == "transit"
      assert Tints.normalize_label("transit") == "transit"

      # A form posts "" for a field nobody typed in, which has to mean the
      # same as never having had one.
      assert Tints.normalize_label("") == nil
      assert Tints.normalize_label("   ") == nil
      assert Tints.normalize_label(nil) == nil
    end

    test "following a tint with no narrowing takes all of it" do
      # What every follow meant before labels existed, and what one that names
      # no subgroup goes on meaning -- so no Plani changes behaviour under it.
      assert Tints.follows?("sky", nil, "sky", [])
      assert Tints.follows?("sky", "transit", "sky", [])
      assert Tints.follows?("sky", "transit", "sky", nil)

      refute Tints.follows?("amber", "transit", "sky", [])
    end

    test "narrowing to a subgroup takes only that subgroup" do
      assert Tints.follows?("sky", "transit", "sky", ["transit"])
      assert Tints.follows?("sky", "weather", "sky", ["transit", "weather"])

      refute Tints.follows?("sky", "weather", "sky", ["transit"])

      # The unlabelled ones are left behind, or the narrowing would do no work.
      refute Tints.follows?("sky", nil, "sky", ["transit"])

      # And the colour still has to match.
      refute Tints.follows?("amber", "transit", "sky", ["transit"])
    end

    test "labels match however they were capitalised" do
      assert Tints.follows?("sky", "Transit", "sky", ["transit"])
      assert Tints.follows?("sky", " transit ", "sky", ["TRANSIT"])
    end

    test "following nothing follows nothing, labels or no labels" do
      refute Tints.follows?("sky", "transit", nil, [])
      refute Tints.follows?("sky", "transit", "", ["transit"])
    end

    test "the subgroups on offer are the ones actually worn under that tint" do
      pairs = [
        {"sky", "transit"},
        {"sky", "Transit"},
        {"sky", "weather"},
        {"sky", nil},
        {"amber", "errands"},
        {nil, "orphan"}
      ]

      assert Tints.labels_in_use(pairs, "sky") == ["transit", "weather"]
      assert Tints.labels_in_use(pairs, "amber") == ["errands"]
      assert Tints.labels_in_use(pairs, "rose") == []
      assert Tints.labels_in_use(pairs, nil) == []
    end
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
