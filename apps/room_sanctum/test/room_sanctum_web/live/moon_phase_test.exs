defmodule RoomSanctumWeb.MoonPhaseTest do
  @moduledoc """
  The moon drawn as the moon actually looks.

  This existed as an off-by-four: the table ran from a full disc at new moon
  round to a dark one at full. Nobody notices a wrong moon for a fortnight, so
  it is worth a test rather than an eye.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RoomSanctumWeb.LivePreview

  defp ephem(phase) do
    render_component(&LivePreview.p_ephem/1, entries: %{data: [%{name: "CPL", phase: phase}]})
  end

  test "a new moon is dark and a full moon is lit" do
    assert ephem(:new_moon) =~ "🌑"
    assert ephem(:full_moon) =~ "🌕"
  end

  test "waxing runs from dark towards full" do
    assert ephem(:waxing_crescent) =~ "🌒"
    assert ephem(:first_quarter) =~ "🌓"
    assert ephem(:waxing_gibbous) =~ "🌔"
  end

  test "waning runs from full back towards dark" do
    assert ephem(:waning_gibbous) =~ "🌖"
    assert ephem(:third_quarter) =~ "🌗"
    assert ephem(:waning_crescent) =~ "🌘"
  end

  test "a phase that has been through JSON reads the same as an atom" do
    # Anything arriving from a publisher rather than from Solarex is a string.
    assert ephem("waning_gibbous") =~ "🌖"
  end

  test "a phase nobody recognises draws nothing rather than raising" do
    # A board somebody is looking at should lose a glyph, not the card.
    html = ephem(:gibbous_but_sideways)
    assert html =~ "CPL"
    refute html =~ "🌕"
  end
end
