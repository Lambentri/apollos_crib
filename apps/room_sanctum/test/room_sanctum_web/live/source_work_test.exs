defmodule RoomSanctumWeb.SourceWorkTest do
  @moduledoc """
  The import queue, across every feed at once.

  The source page shows one feed's bar, which cannot answer "is mine running or
  waiting behind three others" without opening each source in turn. This
  stitches Oban's rows -- the only place a failure survives -- to the live
  progress broadcasts the source page already draws from.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "work#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Bus Feed", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"}
      })

    %{conn: log_in_user(conn, user), user: user, source: source}
  end

  defp job(source_id, state, attrs \\ %{}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    row =
      Map.merge(
        %{
          state: state, queue: "gtfs_import", worker: "RoomGtfs.ImportJob",
          args: %{"source_id" => source_id}, errors: [], tags: [], meta: %{},
          attempt: 0, max_attempts: 3, priority: 0,
          inserted_at: now, scheduled_at: now
        },
        attrs
      )

    {1, [%{id: id}]} = Repo.insert_all("oban_jobs", [row], returning: [:id])
    id
  end

  test "the page lists this user's feeds", %{conn: conn, source: source} do
    {:ok, _live, html} = live(conn, "/cfg/offerings/work")

    assert html =~ source.name
    assert html =~ "Import Queue"
  end

  test "it says the queue runs one at a time, so a waiting feed is not a stuck one", %{conn: conn} do
    {:ok, _live, html} = live(conn, "/cfg/offerings/work")

    assert html =~ "one at a time"
  end

  test "nothing queued says so rather than showing an empty table", %{conn: conn} do
    {:ok, _live, html} = live(conn, "/cfg/offerings/work")

    assert html =~ "Nothing has been queued yet"
  end

  describe "job states" do
    test "Oban's vocabulary is translated into a reader's", %{conn: conn, source: source} do
      job(source.id, "available")

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      # "available" means waiting for the job ahead of it, which is not what
      # the word suggests.
      assert html =~ "waiting"
      refute html =~ ">available<"
    end

    test "a job that gave up shows its error", %{conn: conn, source: source} do
      job(source.id, "discarded", %{
        attempt: 3,
        errors: [%{"error" => "** (MatchError) no match of right hand side\n    at foo.ex:1"}],
        discarded_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      assert html =~ "gave up"
      assert html =~ "MatchError"
      # The stacktrace belongs in the database, not in a table cell.
      refute html =~ "at foo.ex:1"
    end

    test "a running job reads as running", %{conn: conn, source: source} do
      job(source.id, "executing", %{attempt: 1})

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      assert html =~ "running"
      assert html =~ "1/3"
    end
  end

  describe "live progress" do
    test "an idle queue says so rather than showing an empty bar", %{conn: conn} do
      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      assert html =~ "Nothing is importing right now"
      assert html =~ "idle"
    end

    test "a progress broadcast draws that feed's bar", %{conn: conn, source: source} do
      {:ok, live, _html} = live(conn, "/cfg/offerings/work")

      send(live.pid, {:gtfs, to_string(source.id), :stop_times, 5, 10})
      html = render(live)

      assert html =~ "stop times"
      assert html =~ ~s(value="50")
    end

    test "the bundle steps are named the way the source page names them", %{conn: conn, source: source} do
      {:ok, live, _html} = live(conn, "/cfg/offerings/work")

      send(live.pid, {:gtfs, to_string(source.id), :downloading, 1, 4})

      assert render(live) =~ "retrieving bundle"
    end

    test "finishing clears the bar rather than leaving it at its last value", %{conn: conn, source: source} do
      {:ok, live, _html} = live(conn, "/cfg/offerings/work")

      send(live.pid, {:gtfs, to_string(source.id), :stop_times, 9, 10})
      assert render(live) =~ ~s(value="90")

      send(live.pid, {:gtfs, to_string(source.id), :done})
      html = render(live)

      refute html =~ ~s(value="90")
      assert html =~ "Nothing is importing right now"
    end

    test "a feed this user does not own is not shown as running", %{conn: conn, source: source} do
      # The "gtfs" topic carries every source in the installation. Somebody
      # else's import must not appear here, least of all under a name this page
      # cannot resolve.
      {:ok, live, _html} = live(conn, "/cfg/offerings/work")

      send(live.pid, {:gtfs, to_string(source.id + 9999), :stop_times, 5, 10})
      html = render(live)

      assert html =~ "Nothing is importing right now"
      refute html =~ ~s(value="50")
    end

    test "the running feed is named in its own card, and marked in the list", %{
      conn: conn,
      source: source
    } do
      {:ok, live, _html} = live(conn, "/cfg/offerings/work")

      send(live.pid, {:gtfs, to_string(source.id), :stop_times, 5, 10})
      html = render(live)

      assert html =~ "Now running"
      assert html =~ "running"
      refute html =~ "Nothing is importing right now"
    end

    test "a disabled source does not take the page down", %{conn: conn, source: source} do
      {:ok, live, _html} = live(conn, "/cfg/offerings/work")

      send(live.pid, {:gtfs, to_string(source.id), :disabled})

      assert render(live) =~ source.name
    end
  end

  test "another user's feeds are not listed", %{conn: conn} do
    {:ok, stranger} =
      Accounts.register_user(%{
        email: "other#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, theirs} =
      Configuration.create_source(%{
        name: "Not Yours", notes: "", type: :gtfs, enabled: true, user_id: stranger.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/u.zip", "tz" => "UTC"}
      })

    {:ok, _live, html} = live(conn, "/cfg/offerings/work")

    refute html =~ theirs.name
  end
end
