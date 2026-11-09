defmodule RoomGbfs.WorkerDecodeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias RoomGbfs.Worker

  test "a feed body that is JSON decodes with atom keys" do
    assert {:ok, %{data: %{stations: []}}} =
             Worker.decode_feed(~s({"data": {"stations": []}}), 7, "http://x/si.json")
  end

  # %Jason.DecodeError{} has no :reason, so the error branch used to raise a
  # KeyError of its own and take the worker down with it -- over exactly the
  # body (an HTML error page, a truncated download) it was there to survive.
  test "a body that is not JSON is logged and skipped rather than raising" do
    log =
      capture_log(fn ->
        assert :error = Worker.decode_feed("<html>gateway timeout</html>", 7, "http://x/ss.json")
      end)

    assert log =~ "GBFS::7"
    assert log =~ "http://x/ss.json"
  end
end
