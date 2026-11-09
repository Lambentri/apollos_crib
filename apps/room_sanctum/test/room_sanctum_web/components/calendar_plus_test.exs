defmodule RoomSanctumWeb.CalendarPlusTest do
  @moduledoc """
  The Plus calendar card draws what Plus adds -- the hour, the days it runs,
  the place, the repeat -- and the Basic card stays with what Basic sends.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RoomSanctumWeb.LivePreview

  @tz "America/New_York"

  defp today, do: @tz |> DateTime.now!() |> DateTime.to_date()

  defp timed(attrs) do
    start = DateTime.new!(today(), ~T[21:00:00], @tz)

    Map.merge(
      %{
        date_start: today(), summary: "Meeting", description: "Meeting",
        all_day: false, start: start, end: DateTime.add(start, 90, :minute),
        location: nil, repeats: false, tz: @tz
      },
      Map.new(attrs)
    )
  end

  defp all_day(attrs) do
    day = Date.add(today(), 1)

    Map.merge(
      %{
        date_start: day, summary: "Festival", description: "Three days of it",
        all_day: true, start: day, end: Date.add(day, 2),
        location: "Common", repeats: true, tz: @tz
      },
      Map.new(attrs)
    )
  end

  defp plus(entries), do: render_component(&LivePreview.p_plus/1, type: :calendar, entries: %{data: entries})

  test "a timed event shows today and its hours" do
    html = plus([timed(%{})])

    assert html =~ "Meeting"
    assert html =~ "Today"
    assert html =~ "21:00–22:30"
    refute html =~ "Repeats"
  end

  test "an all-day event says how long, where, that it repeats, and what it is" do
    html = plus([all_day(%{})])

    assert html =~ "Tomorrow"
    assert html =~ "All day, until " <> Calendar.strftime(Date.add(today(), 3), "%a %-d %b")
    assert html =~ "Common"
    assert html =~ "Repeats"
    assert html =~ "Three days of it"
  end

  test "a description that only repeats the title is not shown twice" do
    html = plus([timed(%{})])
    assert length(String.split(html, "Meeting")) == 2
  end

  test "Basic shows only what Basic sends" do
    html =
      render_component(&LivePreview.p_basic/1,
        type: :calendar,
        entries: %{data: [%{date_start: today(), summary: "Bins", description: "about bins"}]}
      )

    assert html =~ "Bins"
    assert html =~ Date.to_string(today())
    refute html =~ "about bins"
  end
end
