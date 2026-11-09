defmodule RoomCalendar.WorkerTest do
  use ExUnit.Case, async: true

  alias RoomCalendar.Worker

  # A one-shot HTTP server on a free port, answering every request with `body`.
  defp serve(content_type, body) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    spawn_link(fn ->
      {:ok, sock} = :gen_tcp.accept(listen)
      {:ok, _request} = :gen_tcp.recv(sock, 0)

      :gen_tcp.send(sock, [
        "HTTP/1.1 200 OK\r\ncontent-type: #{content_type}\r\n",
        "content-length: #{byte_size(body)}\r\nconnection: close\r\n\r\n",
        body
      ])

      :gen_tcp.close(sock)
    end)

    "http://127.0.0.1:#{port}/feed"
  end

  test "an HTML page is not an empty calendar" do
    url = serve("text/html; charset=utf-8", "<!doctype html><html></html>")

    assert {:error, reason} = Worker.fetch(url)
    assert reason =~ "not an iCalendar feed"
    assert reason =~ "text/html"
  end

  test "nobody answering is a failed request" do
    assert {:error, "request failed: " <> _} = Worker.fetch("http://127.0.0.1:9/cal.ics")
  end

  test "preview writes out repeating events and keeps what is still to come" do
    future = Date.utc_today() |> Date.add(10) |> Calendar.strftime("%Y%m%d")
    sooner = Date.utc_today() |> Date.add(2) |> Calendar.strftime("%Y%m%d")

    ics = """
    BEGIN:VCALENDAR
    VERSION:2.0
    BEGIN:VEVENT
    UID:later
    SUMMARY:Later
    DTSTART;VALUE=DATE:#{future}
    END:VEVENT
    BEGIN:VEVENT
    UID:past
    SUMMARY:Past
    DTSTART;VALUE=DATE:20010101
    END:VEVENT
    BEGIN:VEVENT
    UID:sooner
    SUMMARY:Sooner
    DTSTART;VALUE=DATE:#{sooner}
    RRULE:FREQ=WEEKLY;COUNT=3
    END:VEVENT
    END:VCALENDAR
    """

    assert {:ok, preview} = Worker.preview(serve("text/calendar", ics))
    assert %{total: 3, upcoming: 4, recurring: 1} = preview
    assert Enum.map(preview.events, & &1.summary) == ["Sooner", "Sooner", "Later", "Sooner"]
  end
end
