defmodule RoomSanctum.JSONTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.JSON

  # Each expectation is what Poison 5 wrote for the same term, which is
  # what the MQTT clients have been reading.
  defmodule Plain do
    defstruct [:name, :at]
  end

  test "a tuple is written as a list, as TupleEncoder did" do
    assert JSON.encode!(%{coordinates: {-73.98, 40.75}}) == ~s({"coordinates":[-73.98,40.75]})
  end

  test "a struct with no encoder of its own is written as its fields" do
    assert Jason.decode!(JSON.encode!(%Plain{name: "a", at: {1, 2}})) == %{
             "name" => "a",
             "at" => [1, 2]
           }
  end

  test "a Decimal is a bare number, not a string" do
    assert JSON.encode!(%{price: Decimal.new("12.50")}) == ~s({"price":12.50})
  end

  test "dates and times are ISO 8601, as both libraries write them" do
    assert JSON.encode!([~D[2026-10-23], ~U[2026-10-23 06:41:00Z]]) ==
             ~s(["2026-10-23","2026-10-23T06:41:00Z"])
  end

  test "ranges and sets become lists, a URI its string" do
    assert JSON.encode!(%{r: 1..3, u: URI.parse("https://example.com/x")}) ==
             ~s({"r":[1,2,3],"u":"https://example.com/x"})

    assert JSON.encode!(MapSet.new([{1, 2}])) == ~s([[1,2]])
  end

  test "pretty printing still works" do
    assert JSON.encode!(%{a: 1}, pretty: true) == ~s({\n  "a": 1\n})
  end
end
