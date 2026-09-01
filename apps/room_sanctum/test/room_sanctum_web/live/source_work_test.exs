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

  defp jobs_for(id) do
    import Ecto.Query

    from(j in "oban_jobs",
      where: j.id == ^id,
      select: %{id: j.id, state: j.state, args: j.args, attempted_at: j.attempted_at}
    )
    |> Repo.all()
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

  describe "days since last run" do
    alias RoomSanctumWeb.SourceLive.Work

    # Written through update_source rather than update_source_meta: the latter
    # merges onto the existing embed, and a source created without one has meta
    # nil rather than empty.
    defp ran_days_ago(source, days) do
      at = DateTime.utc_now() |> DateTime.add(-days * 86_400) |> DateTime.truncate(:second)
      {:ok, source} = Configuration.update_source(source, %{meta: %{last_run: at}})
      source
    end

    test "a feed that has never imported says N", %{source: source} do
      assert Work.days_since_run(source) == "N"
    end

    test "a recent import says nothing at all", %{source: source} do
      # A badge on every feed all the time is a badge nobody reads.
      assert Work.days_since_run(ran_days_ago(source, 1)) == nil
      assert Work.days_since_run(ran_days_ago(source, 3)) == nil
    end

    test "past the threshold it says how many days", %{source: source} do
      assert Work.days_since_run(ran_days_ago(source, 4)) == 4
      assert Work.days_since_run(ran_days_ago(source, 30)) == 30
    end

    test "the chip is on the page, with the reason on hover", %{conn: conn, source: source} do
      ran_days_ago(source, 7)

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      assert html =~ "Last imported 7 days ago"
      assert html =~ ~r/>\s*7\s*</
    end

    test "a never-run feed reads as never rather than as zero days", %{conn: conn} do
      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      assert html =~ "Never imported"
      assert html =~ ~r/>\s*N\s*</
    end

    test "a feed imported today carries no chip", %{conn: conn, source: source} do
      ran_days_ago(source, 0)

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      refute html =~ "Never imported"
      refute html =~ "Last imported"
    end
  end

  describe "clearing a stuck job" do
    alias RoomSanctumWeb.SourceLive.Work

    defp executing_since(source_id, seconds_ago) do
      at =
        DateTime.utc_now()
        |> DateTime.add(-seconds_ago)
        |> DateTime.to_naive()
        |> NaiveDateTime.truncate(:second)

      job(source_id, "executing", %{attempt: 1, attempted_at: at})
    end

    test "a job running for a few minutes is not called stranded", %{source: source} do
      id = executing_since(source.id, 300)
      [job] = jobs_for(id)

      refute Work.stranded?(job, %{})
    end

    test "an hour of silence is", %{source: source} do
      id = executing_since(source.id, 7_200)
      [job] = jobs_for(id)

      assert Work.stranded?(job, %{})
    end

    test "a job still broadcasting is alive whatever the clock says", %{source: source} do
      id = executing_since(source.id, 7_200)
      [job] = jobs_for(id)

      progress = %{to_string(source.id) => %{step: :stop_times, value: 40, at: DateTime.utc_now()}}

      refute Work.stranded?(job, progress)
    end

    test "a job that is not executing is never stranded", %{source: source} do
      id = job(source.id, "completed")
      [job] = jobs_for(id)

      refute Work.stranded?(job, %{})
    end

    test "the page warns when a feed is blocked by one", %{conn: conn, source: source} do
      executing_since(source.id, 7_200)

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      assert html =~ "marked running with nothing"
      # Why it matters, not just that it happened.
      assert html =~ "cannot be queued again"
    end

    test "clearing frees the feed", %{conn: conn, source: source} do
      id = executing_since(source.id, 7_200)

      {:ok, live, _html} = live(conn, "/cfg/offerings/work")
      render_click(live, "clear", %{"id" => to_string(id)})

      [job] = jobs_for(id)
      # Cancelled is outside the states ImportJob's uniqueness counts, which is
      # what lets the next import through.
      assert job.state == "cancelled"
    end

    test "only executing jobs offer the button", %{conn: conn, source: source} do
      job(source.id, "completed")

      {:ok, _live, html} = live(conn, "/cfg/offerings/work")

      refute html =~ ~s(phx-click="clear")
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
