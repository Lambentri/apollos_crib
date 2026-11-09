defmodule RoomSanctumWeb.QueryShowOwnershipTest do
  @moduledoc """
  The query page is the user's own: another user's query is not found, the
  visions it offers to pin to are the user's, and a vision id sent by the
  client is checked rather than trusted.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo}

  defp user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "owner#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    user
  end

  defp query_for(user, symbol) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "Markets #{symbol}",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    {:ok, query} =
      Configuration.create_query(%{
        name: "Query #{symbol}",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => symbol}
      })

    query
  end

  setup %{conn: conn} do
    me = user()
    them = user()

    {:ok, mine} = Configuration.create_vision(%{name: "My dash", user_id: me.id})
    {:ok, theirs} = Configuration.create_vision(%{name: "Their dash", user_id: them.id})

    %{
      conn: log_in_user(conn, me),
      me: me,
      them: them,
      my_query: query_for(me, "AAPL"),
      their_query: query_for(them, "SECRET"),
      mine: mine,
      theirs: theirs
    }
  end

  defp open_panel(conn, query) do
    {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))
    send(live.pid, :update_sec)
    _ = render(live)
    render_click(live, "toggle-sel", %{})
    live
  end

  test "another user's query is not found, the same as a missing one", ctx do
    assert_raise Ecto.NoResultsError, fn ->
      live(ctx.conn, Routes.query_show_path(ctx.conn, :show, ctx.their_query))
    end

    assert_raise Ecto.NoResultsError, fn ->
      live(ctx.conn, Routes.query_show_path(ctx.conn, :show, ctx.their_query.id + 100_000))
    end
  end

  test "another user's query cannot be opened for editing either", ctx do
    assert_raise Ecto.NoResultsError, fn ->
      live(ctx.conn, Routes.query_show_path(ctx.conn, :edit, ctx.their_query))
    end
  end

  test "the user's own query opens", ctx do
    {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, ctx.my_query))

    assert html =~ ctx.my_query.name
  end

  test "only the user's own visions are offered to pin to", ctx do
    live = open_panel(ctx.conn, ctx.my_query)

    assert has_element?(live, ~s([phx-click="add-to"][phx-value-vision="#{ctx.mine.id}"]))
    refute has_element?(live, ~s([phx-click="add-to"][phx-value-vision="#{ctx.theirs.id}"]))
  end

  test "pinning to another user's vision by a forged event is refused", ctx do
    live = open_panel(ctx.conn, ctx.my_query)

    html = render_click(live, "add-to", %{"vision" => to_string(ctx.theirs.id)})

    # Not even its name: the refusal used to be "Could not add this to <name>".
    refute html =~ ctx.theirs.name

    theirs = Repo.reload!(ctx.theirs)
    assert theirs.query_ids in [nil, []]
    assert theirs.queries == []
  end

  test "unpinning from another user's vision by a forged event is refused", ctx do
    # Stored before the vision changeset checked ownership: their vision
    # holding my query. Only its owner gets to take it off. Written straight
    # to the row, since the changeset now refuses it in both places.
    embed = %{
      "id" => nil,
      "type" => "pinned",
      "data" => %{"order" => 0, "query" => ctx.my_query.id, "__type__" => "pinned"}
    }

    Repo.query!("UPDATE cfg_visions SET queries = $1, query_ids = $2 WHERE id = $3", [
      [embed],
      [ctx.my_query.id],
      ctx.theirs.id
    ])

    theirs = Repo.reload!(ctx.theirs)

    live = open_panel(ctx.conn, ctx.my_query)
    render_click(live, "remove-from", %{"vision" => to_string(theirs.id)})

    after_forgery = Repo.reload!(theirs)
    assert after_forgery.query_ids == [ctx.my_query.id]
    assert length(after_forgery.queries) == 1
  end

  test "pinning to the user's own vision still works", ctx do
    live = open_panel(ctx.conn, ctx.my_query)

    render_click(live, "add-to", %{"vision" => to_string(ctx.mine.id)})

    assert Repo.reload!(ctx.mine).query_ids == [ctx.my_query.id]
  end
end
