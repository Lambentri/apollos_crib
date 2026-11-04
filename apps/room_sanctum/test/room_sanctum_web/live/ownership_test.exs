defmodule RoomSanctumWeb.OwnershipTest do
  @moduledoc """
  The /cfg pages only reach the signed-in user's own records. Another user's
  id -- in the URL, or in an event the client sends -- gets the same
  not-found a missing one does, and changes nothing.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo}

  defp user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "own#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    user
  end

  defp source_for(user, name \\ "Markets") do
    {:ok, source} =
      Configuration.create_source(%{
        name: name,
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    source
  end

  defp query_for(user) do
    source = source_for(user)

    {:ok, query} =
      Configuration.create_query(%{
        name: "Their query",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "SECRET"}
      })

    query
  end

  # A lookup that raises takes the LiveView down with it, as a missing id
  # always has; the test only cares that nothing was changed on the way.
  defp forge(live, event, params) do
    Process.flag(:trap_exit, true)
    catch_exit(render_click(live, event, params))
  end

  setup %{conn: conn} do
    me = user()
    %{conn: log_in_user(conn, me), me: me, them: user()}
  end

  describe "the query list" do
    test "will not open another user's query for editing", ctx do
      theirs = query_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.query_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will not delete another user's query", ctx do
      theirs = query_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.query_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end
  end

  defp vision_for(user, name) do
    {:ok, vision} = Configuration.create_vision(%{name: name, user_id: user.id})
    vision
  end

  defp pythiae_for(user, visions) do
    {:ok, pythiae} =
      Configuration.create_pythiae(%{
        name: "screen-#{System.unique_integer([:positive])}",
        user_id: user.id,
        ankyra: [],
        visions: visions,
        curr_vision: List.first(visions)
      })

    pythiae
  end

  describe "the vision pages" do
    test "will not show another user's vision", ctx do
      theirs = vision_for(ctx.them, "Their dash")

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.vision_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's vision for editing", ctx do
      theirs = vision_for(ctx.them, "Their dash")

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.vision_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will not delete another user's vision", ctx do
      theirs = vision_for(ctx.them, "Their dash")
      {:ok, live, _html} = live(ctx.conn, Routes.vision_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end

    test "will not put the vision on another user's pythiae", ctx do
      mine = vision_for(ctx.me, "My dash")
      their_screen = pythiae_for(ctx.them, [])
      {:ok, live, _html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :show, mine))

      forge(live, "add-to-pythiae", %{"pythiae" => to_string(their_screen.id)})

      assert Repo.reload!(their_screen).visions == []
    end

    test "neither lists nor edits another user's pythiae that holds the vision", ctx do
      mine = vision_for(ctx.me, "My dash")
      their_screen = pythiae_for(ctx.them, [mine.id])
      {:ok, live, _html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :show, mine))
      send(live.pid, :update_sec)
      render_click(live, "toggle-pythiae-sel", %{})

      refute has_element?(
               live,
               ~s([phx-click="remove-from-pythiae"][phx-value-pythiae="#{their_screen.id}"])
             )

      forge(live, "remove-from-pythiae", %{"pythiae" => to_string(their_screen.id)})

      assert Repo.reload!(their_screen).visions == [mine.id]
    end
  end

  defp gtfs_source_for(user) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "Their buses",
        notes: "",
        type: :gtfs,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"}
      })

    source
  end

  defp import_jobs(source_id, state \\ nil) do
    import Ecto.Query

    from(j in "oban_jobs",
      where:
        j.queue == "gtfs_import" and fragment("(?->>'source_id')::int", j.args) == ^source_id,
      select: j.state
    )
    |> Repo.all()
    |> Enum.filter(&(is_nil(state) or &1 == state))
  end

  describe "the source pages" do
    test "will not show another user's source", ctx do
      theirs = source_for(ctx.them, "Their markets")

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.source_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's source for editing", ctx do
      theirs = source_for(ctx.them, "Their markets")

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.source_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will neither delete nor disable another user's source", ctx do
      theirs = source_for(ctx.them, "Their markets")
      {:ok, live, _html} = live(ctx.conn, Routes.source_index_path(ctx.conn, :index))

      forge(live, "toggle-source-enabled", %{"id" => to_string(theirs.id), "current" => "true"})
      assert Repo.reload!(theirs).enabled

      {:ok, live, _html} = live(ctx.conn, Routes.source_index_path(ctx.conn, :index))
      forge(live, "delete", %{"id" => to_string(theirs.id)})
      assert Repo.reload(theirs)
    end

    test "the import queue will not queue another user's feed", ctx do
      theirs = gtfs_source_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, "/cfg/offerings/work")

      render_click(live, "requeue", %{"id" => to_string(theirs.id)})

      assert import_jobs(theirs.id) == []
    end

    test "the import queue will not clear another user's job", ctx do
      theirs = gtfs_source_for(ctx.them)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {1, [%{id: job_id}]} =
        Repo.insert_all(
          "oban_jobs",
          [
            %{
              state: "executing",
              queue: "gtfs_import",
              worker: "RoomGtfs.ImportJob",
              args: %{"source_id" => theirs.id},
              errors: [],
              tags: [],
              meta: %{},
              attempt: 1,
              max_attempts: 3,
              priority: 0,
              inserted_at: now,
              scheduled_at: now,
              attempted_at: now
            }
          ],
          returning: [:id]
        )

      {:ok, live, _html} = live(ctx.conn, "/cfg/offerings/work")
      render_click(live, "clear", %{"id" => to_string(job_id)})

      assert import_jobs(theirs.id) == ["executing"]
    end
  end
end
