defmodule RoomSanctum.GtfsHeadersTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias RoomSanctum.Configuration.Configs.GTFS

  defp change(attrs) do
    GTFS.changeset(%GTFS{}, Map.merge(%{"url" => "http://x/gtfs.zip", "tz" => "UTC"}, attrs))
  end

  describe "parsing what a person typed" do
    test "one header per line" do
      assert {:ok, %{"Authorization" => "Bearer abc", "x-api-key" => "k"}} =
               GTFS.parse_headers("Authorization: Bearer abc\nx-api-key: k")
    end

    test "a value may contain colons" do
      # Split on the first colon only: a Bearer token or a URL in a header
      # value is not two headers.
      assert {:ok, %{"Authorization" => "Bearer a:b:c"}} =
               GTFS.parse_headers("Authorization: Bearer a:b:c")
    end

    test "blank lines and stray whitespace are not headers" do
      assert {:ok, %{"apikey" => "spaced"}} = GTFS.parse_headers("\n  apikey:   spaced  \n\n")
    end

    test "a line with no colon is an error naming the line" do
      assert {:error, "no colon here"} = GTFS.parse_headers("no colon here")
    end

    test "a name with a space in it is rejected" do
      # Nearly always a colon typed into the previous line's value.
      assert {:error, _} = GTFS.parse_headers("bad name: x")
    end

    test "nothing typed is no headers, not an error" do
      assert {:ok, %{}} = GTFS.parse_headers("")
    end
  end

  describe "the changeset" do
    test "valid text becomes the stored map" do
      assert %{"Authorization" => "Bearer zzz"} =
               change(%{"headers_raw" => "Authorization: Bearer zzz"})
               |> Changeset.get_field(:headers)
    end

    test "a bad line fails the changeset rather than storing half of it" do
      changeset = change(%{"headers_raw" => "oops"})

      refute changeset.valid?
      assert changeset.errors[:headers_raw]
    end

    test "a form that does not mention headers leaves them alone" do
      # Anything editing a source by another route must not wipe its key.
      existing = %GTFS{headers: %{"keep" => "me"}}

      assert %{"keep" => "me"} =
               GTFS.changeset(existing, %{"url" => "http://x", "tz" => "UTC"})
               |> Changeset.get_field(:headers)
    end

    test "clearing the box clears the headers" do
      existing = %GTFS{headers: %{"gone" => "soon"}}

      assert %{} ==
               GTFS.changeset(existing, %{"url" => "http://x", "tz" => "UTC", "headers_raw" => ""})
               |> Changeset.get_field(:headers)
    end
  end

  describe "what the worker sends" do
    test "the stored map becomes a header list" do
      assert [{"x-api-key", "k"}] = GTFS.request_headers(%{headers: %{"x-api-key" => "k"}})
    end

    test "a source with none makes the request it always made" do
      assert [] == GTFS.request_headers(%{headers: %{}})
      assert [] == GTFS.request_headers(%{})
      assert [] == GTFS.request_headers(nil)
    end
  end

  describe "round tripping" do
    test "stored headers render back as the text that made them" do
      text = "Authorization: Bearer abc\nx-api-key: k"
      {:ok, parsed} = GTFS.parse_headers(text)

      assert GTFS.headers_text(%{headers: parsed}) == text
    end

    test "the text is ordered, so opening a form twice shows the same thing" do
      assert GTFS.headers_text(%{headers: %{"b" => "2", "a" => "1"}}) == "a: 1\nb: 2"
    end
  end
end
