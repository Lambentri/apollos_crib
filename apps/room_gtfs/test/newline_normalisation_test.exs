defmodule RoomGtfs.NewlineNormalisationTest do
  @moduledoc """
  Feeds disagree about line endings, and COPY is unforgiving about it: Postgres
  infers the newline style from the first terminator, so CR CR LF (Caltrain's
  trips.txt) reads as CR-terminated and every second line comes out empty.

  The normaliser is private, so these drive it the way the importer does --
  through a stream of chunks -- via the public entry point used in tests.
  """
  use ExUnit.Case, async: true

  alias RoomGtfs.Worker.Static

  defp normalize(chunks) do
    chunks
    |> Static.normalize_newlines_for_test()
    |> Enum.join()
  end

  test "leaves plain LF alone" do
    assert normalize(["a,b\n1,2\n"]) == "a,b\n1,2\n"
  end

  test "converts CRLF to LF" do
    assert normalize(["a,b\r\n1,2\r\n"]) == "a,b\n1,2\n"
  end

  test "collapses the CR CR LF that breaks the import" do
    assert normalize(["a,b\r\r\n1,2\r\r\n"]) == "a,b\n1,2\n"
  end

  test "collapses arbitrarily long CR runs" do
    assert normalize(["a,b\r\r\r\r\n1,2\n"]) == "a,b\n1,2\n"
  end

  test "treats a lone CR as a terminator so CR-only files still load" do
    assert normalize(["a,b\r1,2\r"]) == "a,b\n1,2\n"
  end

  test "a CR run split across chunks is still collapsed" do
    # the boundary case: the CRs end one chunk, the LF starts the next
    assert normalize(["a,b\r", "\r\n1,2\n"]) == "a,b\n1,2\n"
    assert normalize(["a,b\r\r", "\n1,2\n"]) == "a,b\n1,2\n"
    assert normalize(["a,b", "\r\r\n", "1,2\n"]) == "a,b\n1,2\n"
  end

  test "a trailing CR at end of input is not swallowed" do
    assert normalize(["a,b\n1,2\r"]) == "a,b\n1,2\n"
  end

  test "does not invent or drop records" do
    caltrain = "route_id,service_id,trip_id\r\r\n77119,c_717,163\r\r\n77119,c_717,167\r\r\n"

    lines = caltrain |> List.wrap() |> normalize() |> String.split("\n", trim: true)

    assert length(lines) == 3
    assert hd(lines) == "route_id,service_id,trip_id"
    assert List.last(lines) == "77119,c_717,167"
  end

  test "content is otherwise untouched" do
    row = ~s(1,"Main St, Apt 2",x\r\r\n)
    assert normalize([row]) == ~s(1,"Main St, Apt 2",x\n)
  end
end
