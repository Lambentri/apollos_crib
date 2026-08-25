defmodule RoomGtfs.ZipTailTest do
  @moduledoc """
  511.org appends an HTML fragment to every GTFS download -- 680 bytes of
  `<!DOCTYPE html ...>` after the end-of-central-directory record, while
  declaring a comment length of zero. `unzip` reads the archive anyway; Unzip
  looks for the EOCD at the tail of the blob and reports "missing EOCD record",
  so a ten megabyte feed fails to import over 680 bytes of markup.
  """
  use ExUnit.Case, async: true

  alias RoomGtfs.Worker.Static

  # A real archive, built rather than checked in, so the fixture cannot drift
  # from what the zip format actually produces.
  defp zip_bytes do
    {:ok, {_name, bytes}} =
      :zip.create(~c"feed.zip", [{~c"agency.txt", "agency_id,agency_name\nX,Example\n"}], [:memory])

    bytes
  end

  defp readable?(blob) do
    match?({:ok, _}, blob |> Unzip.InMem.new() |> Unzip.new())
  end

  test "a well-formed archive is returned untouched" do
    blob = zip_bytes()
    assert Static.trim_zip_tail(blob) == blob
    assert readable?(blob)
  end

  test "html appended after the EOCD is trimmed, and the archive then reads" do
    blob = zip_bytes()
    junk = "\r\n\r\n<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\">\n</html>\r\n"
    polluted = blob <> junk

    refute readable?(polluted), "precondition: the polluted blob is what Unzip rejects"

    trimmed = Static.trim_zip_tail(polluted)
    assert trimmed == blob
    assert readable?(trimmed)
  end

  test "a declared comment is kept, since it is part of the archive" do
    # Trimming to EOCD+22 unconditionally would truncate a legal comment and
    # leave the record claiming bytes that are no longer there.
    blob = zip_bytes()
    comment = "built by a publisher that uses the comment field"
    len = byte_size(comment)

    # The comment length lives in the last two bytes of the EOCD record.
    with_comment = binary_part(blob, 0, byte_size(blob) - 2) <> <<len::16-little>> <> comment

    assert Static.trim_zip_tail(with_comment) == with_comment
  end

  test "a body that is not a zip at all is left alone to fail downstream" do
    # The decoder's own error is more informative than anything this could say.
    assert Static.trim_zip_tail("<html>not a zip</html>") == "<html>not a zip</html>"
    assert Static.trim_zip_tail(<<>>) == <<>>
  end
end
