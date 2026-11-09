defmodule RoomSanctumWeb.SourceLiveCalendarPreviewTest do
  @moduledoc """
  A calendar source's page: what is stored for it, and a live fetch of its URL
  that says plainly when the URL is not a calendar.

  Builds its own user and source, as ConfigurationFixtures' source_fixture
  predates the required user_id.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Storage}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "calendar#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  setup %{user: user} do
    {:ok, source} =
      Configuration.create_source(%{
        name: "Bins",
        notes: "",
        type: :calendar,
        enabled: true,
        user_id: user.id,
        # Nothing listens here, so the preview fails fast and offline.
        config: %{"__type__" => "calendar", "url" => "http://127.0.0.1:9/cal.ics"}
      })

    %{source: source}
  end

  defp store(source, summary, start, finish) do
    {:ok, _} =
      Storage.create_icalendar(%{
        source_id: source.id,
        date_start: start,
        date_end: finish,
        blob: %{"summary" => summary, "location" => "Kerb"}
      })
  end

  test "shows upcoming stored entries, all-day ones as dates", %{conn: conn, source: source} do
    day = Date.utc_today() |> Date.add(3)
    start = DateTime.new!(day, ~T[00:00:00])
    store(source, "Recycling", start, DateTime.add(start, 1, :day))
    store(source, "Long gone", ~U[2001-01-01 00:00:00Z], ~U[2001-01-02 00:00:00Z])

    {:ok, _view, html} = live(conn, Routes.source_show_path(conn, :show, source))

    assert html =~ "2 entries stored"
    assert html =~ "Recycling"
    assert html =~ "Kerb"
    assert html =~ Calendar.strftime(start, "%a %-d %b %Y")
    refute html =~ "Long gone"
  end

  # The fetch itself is room_calendar's, which this app does not depend on and
  # so cannot reach under its own test run; RoomCalendar.WorkerTest covers it.
  # Here only that the page has nothing stored and offers the preview.
  test "an empty source says so and offers a preview", %{conn: conn, source: source} do
    {:ok, view, html} = live(conn, Routes.source_show_path(conn, :show, source))

    assert html =~ "Nothing stored yet"
    assert html =~ "Nothing is stored."
    assert has_element?(view, "button[phx-click=ical-preview]")
  end
end
