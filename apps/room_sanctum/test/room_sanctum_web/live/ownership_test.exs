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
      # Planted past the changeset, which no longer lets their pythiae take
      # someone else's vision -- as one saved before it checked could have.
      their_screen =
        Repo.insert!(%Configuration.Pythiae{
          name: "screen-#{System.unique_integer([:positive])}",
          user_id: ctx.them.id,
          ankyra: [],
          visions: [mine.id],
          curr_vision: mine.id
        })

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

  defp import_job!(source, errors \\ []) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {1, [%{id: job_id}]} =
      Repo.insert_all(
        "oban_jobs",
        [
          %{
            state: "executing",
            queue: "gtfs_import",
            worker: "RoomGtfs.ImportJob",
            args: %{"source_id" => source.id},
            errors: errors,
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

    job_id
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
      job_id = import_job!(theirs)

      {:ok, live, _html} = live(ctx.conn, "/cfg/offerings/work")
      render_click(live, "clear", %{"id" => to_string(job_id)})

      assert import_jobs(theirs.id) == ["executing"]
    end

    test "the import queue lists only the user's own jobs", ctx do
      mine = import_job!(gtfs_source_for(ctx.me))
      theirs = import_job!(gtfs_source_for(ctx.them), [%{"error" => "their secret failure"}])

      {:ok, live, _html} = live(ctx.conn, "/cfg/offerings/work")

      assert has_element?(live, "#job-#{mine}")
      refute has_element?(live, "#job-#{theirs}")
      refute render(live) =~ "their secret failure"
    end
  end

  defp foci_for(user) do
    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home",
        user_id: user.id,
        place: %Geo.Point{coordinates: {-71.0589, 42.3601}, srid: 4326}
      })

    foci
  end

  describe "the foci pages" do
    test "will not show another user's foci", ctx do
      theirs = foci_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.foci_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's foci for editing", ctx do
      theirs = foci_for(ctx.them)

      for action <- [:edit, :edit_coords] do
        assert_raise Ecto.NoResultsError, fn ->
          live(ctx.conn, Routes.foci_index_path(ctx.conn, action, theirs))
        end
      end
    end

    test "will not delete another user's foci", ctx do
      theirs = foci_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.foci_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end

    test "will not make queries on another user's source", ctx do
      mine = foci_for(ctx.me)

      {:ok, their_source} =
        Configuration.create_source(%{
          name: "Their sky",
          notes: "",
          type: :ephem,
          enabled: true,
          user_id: ctx.them.id,
          config: %{"__type__" => "ephem"}
        })

      {:ok, live, _html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :show, mine))

      render_click(live, "create-queries-for-sources", %{
        "source_ids" => [to_string(their_source.id)]
      })

      assert Configuration.get_queries(:source, their_source.id) == []
    end
  end

  # users_rabbit comes from the hermes repo's migrations and is not in the
  # sanctum test database, and the pages that list Ankyra need it to mount. It
  # is made inside the test's sandbox transaction, so it goes when the test does.
  defp users_rabbit!(_ctx) do
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS users_rabbit (
      id bigserial PRIMARY KEY,
      password varchar,
      username uuid,
      topic varchar,
      client_ids varchar[] DEFAULT '{}',
      auto_register_clients boolean DEFAULT true,
      user_id bigint,
      inserted_at timestamp,
      updated_at timestamp
    )
    """)

    :ok
  end

  describe "the pythiae pages" do
    setup :users_rabbit!

    test "will not show another user's pythiae", ctx do
      theirs = pythiae_for(ctx.them, [])

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.pythiae_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's pythiae for editing", ctx do
      theirs = pythiae_for(ctx.them, [])

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.pythiae_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will not delete another user's pythiae", ctx do
      theirs = pythiae_for(ctx.them, [])
      {:ok, live, _html} = live(ctx.conn, Routes.pythiae_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end

    test "will not point the pythiae at another user's vision or foci", ctx do
      mine = vision_for(ctx.me, "My dash")
      screen = pythiae_for(ctx.me, [mine.id])
      their_vision = vision_for(ctx.them, "Their dash")
      their_foci = foci_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.pythiae_show_path(ctx.conn, :show, screen))

      render_click(live, "set-current-vision", %{"id" => to_string(their_vision.id)})
      render_click(live, "set-current-foci", %{"id" => to_string(their_foci.id)})

      screen = Repo.reload!(screen)
      assert screen.curr_vision == mine.id
      assert screen.curr_foci == nil
    end

    test "still points the pythiae at the user's own vision", ctx do
      first = vision_for(ctx.me, "First")
      second = vision_for(ctx.me, "Second")
      screen = pythiae_for(ctx.me, [first.id, second.id])
      {:ok, live, _html} = live(ctx.conn, Routes.pythiae_show_path(ctx.conn, :show, screen))

      render_click(live, "set-current-vision", %{"id" => to_string(second.id)})

      assert Repo.reload!(screen).curr_vision == second.id
    end
  end

  defp plani_for(user) do
    {:ok, plani} =
      Configuration.create_plani(%{
        name: "Pocket",
        user_id: user.id,
        home_foci_id: foci_for(user).id,
        sources: []
      })

    plani
  end

  describe "the plani pages" do
    setup :users_rabbit!

    test "will not show another user's plani", ctx do
      theirs = plani_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.plani_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's plani for editing", ctx do
      theirs = plani_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.plani_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will not delete another user's plani", ctx do
      theirs = plani_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.plani_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end
  end

  defp ankyra_for(user) do
    {:ok, ankyra} =
      Accounts.create_rabbit_user(%{
        username: Ecto.UUID.generate(),
        password: "hunter2",
        topic: "Their-Topic",
        user_id: user.id
      })

    ankyra
  end

  describe "the ankyra pages" do
    setup :users_rabbit!

    test "will not show another user's ankyra", ctx do
      theirs = ankyra_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.ankyra_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's ankyra for editing", ctx do
      theirs = ankyra_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.ankyra_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will not delete another user's ankyra", ctx do
      theirs = ankyra_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.ankyra_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end

    test "deletes the user's own ankyra", ctx do
      mine = ankyra_for(ctx.me)
      {:ok, live, _html} = live(ctx.conn, Routes.ankyra_index_path(ctx.conn, :index))

      render_click(live, "delete", %{"id" => to_string(mine.id)})

      refute Repo.reload(mine)
    end
  end

  defp scribus_for(user) do
    {:ok, scribus} =
      Configuration.create_scribus({:user, user.id}, %{
        name: "Kitchen",
        resolution: "800x480",
        vision: vision_for(user, "Board").id,
        enabled: true,
        color: :untouched,
        theme: :inky
      })

    scribus
  end

  describe "the scribus pages" do
    test "list only the user's own scribus", ctx do
      mine = scribus_for(ctx.me)
      theirs = scribus_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.scribus_index_path(ctx.conn, :index))

      assert has_element?(live, "#cfg_scribus-#{mine.id}")
      refute has_element?(live, "#cfg_scribus-#{theirs.id}")
    end

    test "show and edit the user's own scribus", ctx do
      mine = scribus_for(ctx.me)

      assert {:ok, _live, _html} = live(ctx.conn, Routes.scribus_show_path(ctx.conn, :show, mine))

      assert {:ok, _live, _html} =
               live(ctx.conn, Routes.scribus_index_path(ctx.conn, :edit, mine))
    end

    test "will not show another user's scribus", ctx do
      theirs = scribus_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.scribus_show_path(ctx.conn, :show, theirs))
      end
    end

    test "will not open another user's scribus for editing", ctx do
      theirs = scribus_for(ctx.them)

      for path <- [
            Routes.scribus_index_path(ctx.conn, :edit, theirs),
            Routes.scribus_show_path(ctx.conn, :edit, theirs)
          ] do
        assert_raise Ecto.NoResultsError, fn -> live(ctx.conn, path) end
      end
    end

    test "will not delete another user's scribus", ctx do
      theirs = scribus_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.scribus_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end

    test "deletes the user's own scribus", ctx do
      mine = scribus_for(ctx.me)
      {:ok, live, _html} = live(ctx.conn, Routes.scribus_index_path(ctx.conn, :index))

      render_click(live, "delete", %{"id" => to_string(mine.id)})

      refute Repo.reload(mine)
    end

    test "a new scribus belongs to whoever made it, whatever the form says", ctx do
      vision = vision_for(ctx.me, "Board")
      {:ok, live, _html} = live(ctx.conn, Routes.scribus_index_path(ctx.conn, :new))

      live
      |> form("#scribus-form")
      |> render_submit(%{
        "scribus" => %{
          "name" => "Hall",
          "resolution" => "800x480",
          "vision" => to_string(vision.id),
          "enabled" => "true",
          "color" => "untouched",
          "theme" => "inky",
          "user_id" => to_string(ctx.them.id)
        }
      })

      assert [%{user_id: owner}] = Repo.all(Configuration.Scribus)
      assert owner == ctx.me.id
    end

    test "a scribus cannot show another user's vision", ctx do
      mine = scribus_for(ctx.me)
      their_vision = vision_for(ctx.them, "Their board")

      assert {:error, _} = Configuration.update_scribus(mine, %{vision: their_vision.id})
      assert Repo.reload!(mine).vision != their_vision.id
    end
  end

  describe "the keryx pages" do
    setup ctx do
      {:ok, theirs} =
        Configuration.create_keryx(%{
          name: "their herald",
          ttl: 60,
          query_ids: [query_for(ctx.them).id],
          user_id: ctx.them.id
        })

      %{theirs: theirs}
    end

    test "will not show another user's keryx", ctx do
      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.keryx_show_path(ctx.conn, :show, ctx.theirs))
      end
    end

    test "will not open another user's keryx for editing", ctx do
      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.keryx_index_path(ctx.conn, :edit, ctx.theirs))
      end
    end

    test "will not delete another user's keryx", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.keryx_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(ctx.theirs.id)})

      assert Repo.reload(ctx.theirs)
    end
  end
end
