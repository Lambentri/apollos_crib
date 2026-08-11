defmodule RoomGtfs.RtResponseTest do
  @moduledoc """
  A dead GTFS-RT endpoint rarely says so with a status code. MBTA's CDN answers
  a missing object with HTTP 200 and an S3 AccessDenied document; fed to the
  protobuf decoder that surfaces as "closing group 7 but no groups are open",
  which is true and tells you nothing about the URL being wrong.
  """
  use ExUnit.Case, async: true

  alias RoomGtfs.Worker.RT

  defp response(content_type, body) do
    headers = if content_type, do: [{"Content-Type", content_type}], else: []
    %{headers: headers, body: body}
  end

  test "protobuf content types are accepted" do
    for type <- ["application/x-protobuf", "application/octet-stream", "application/protobuf"] do
      assert RT.protobuf_response?(response(type, <<10, 5>>)), type
    end
  end

  test "the header is matched case-insensitively and past any charset" do
    assert RT.protobuf_response?(%{
             headers: [{"content-type", "Application/X-Protobuf; charset=binary"}],
             body: <<10>>
           })
  end

  test "an error document is rejected however it is served" do
    refute RT.protobuf_response?(response("application/xml", ~s(<?xml version="1.0"?><Error/>)))
    refute RT.protobuf_response?(response("text/html; charset=utf-8", "<!DOCTYPE HTML><h1>500</h1>"))
    refute RT.protobuf_response?(response("application/json", ~s({"error":"nope"})))
  end

  test "the s3 access-denied body that started this is rejected" do
    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Error><Code>AccessDenied</Code><Message>not authorized</Message></Error>
    """

    refute RT.protobuf_response?(response("application/xml", body))
  end

  test "with no content type at all, markup is still rejected" do
    refute RT.protobuf_response?(response(nil, ~s(<?xml version="1.0"?><Error/>)))
    refute RT.protobuf_response?(response(nil, "<!DOCTYPE HTML>"))
    refute RT.protobuf_response?(response(nil, "  \n <html><body>oops</body></html>"))
  end

  test "with no content type, binary is given the benefit of the doubt" do
    assert RT.protobuf_response?(response(nil, <<10, 5, 1, 2, 3>>))
  end

  test "a stated protobuf type wins over a body that looks like markup" do
    # a feed whose first bytes happen to resemble markup is still protobuf
    assert RT.protobuf_response?(response("application/x-protobuf", "<?xml"))
  end
end
