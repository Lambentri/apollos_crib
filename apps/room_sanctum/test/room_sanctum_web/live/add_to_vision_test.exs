defmodule RoomSanctumWeb.AddToVisionTest do
  @moduledoc """
  Pinning a query to a vision from the query page.

  A vision tracks its queries twice -- an embedded list for ordering, and a
  plain array of ids -- and both have to move together, or the query page will
  not know it belongs to the vision.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "vision#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Markets", notes: "", type: :bourse, enabled: true,
        user_id: user.id, config: %{"__type__" => "bourse"}
      })

    {:ok, vision} = Configuration.create_vision(%{name: "Dash", user_id: user.id})

    %{conn: log_in_user(conn, user), user: user, source: source, vision: vision}
  end

  defp query(%{user: user, source: source}, symbol) do
    {:ok, query} =
      Configuration.create_query(%{
        name: symbol, notes: "", source_id: source.id, user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => symbol}
      })

    query
  end

  defp add(conn, query, vision) do
    {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))
    send(live.pid, :update_sec)
    _ = render(live)
    render_click(live, "add-to", %{"vision" => to_string(vision.id)})
    Process.sleep(50)
    Configuration.get_vision!(vision.id)
  end

  test "a query is pinned to the vision", ctx do
    q = query(ctx, "AAPL")

    vision = add(ctx.conn, q, ctx.vision)

    assert vision.query_ids == [q.id]
    assert length(vision.queries) == 1
  end

  test "a second query is pinned too", ctx do
    a = query(ctx, "AAPL")
    b = query(ctx, "MSFT")

    add(ctx.conn, a, ctx.vision)
    vision = add(ctx.conn, b, ctx.vision)

    # the bug: query_ids kept only the first, while the embedded list grew
    assert vision.query_ids == [a.id, b.id]
    assert length(vision.queries) == 2
  end

  test "each query's page then knows about the vision", ctx do
    a = query(ctx, "AAPL")
    b = query(ctx, "MSFT")

    add(ctx.conn, a, ctx.vision)
    add(ctx.conn, b, ctx.vision)

    for q <- [a, b] do
      assert length(Configuration.get_visions(:query, to_string(q.id))) == 1,
             "#{q.name} did not show its vision"
    end
  end

  test "a vision already holding the query stops offering itself", ctx do
    a = query(ctx, "AAPL")

    assert length(Configuration.get_visions_nv(:query, to_string(a.id))) == 1
    add(ctx.conn, a, ctx.vision)
    assert Configuration.get_visions_nv(:query, to_string(a.id)) == []
  end

  test "adding the same query twice does not duplicate it", ctx do
    a = query(ctx, "AAPL")

    add(ctx.conn, a, ctx.vision)
    vision = add(ctx.conn, a, ctx.vision)

    assert vision.query_ids == [a.id]
    assert length(vision.queries) == 1
  end

  describe "into a vision that does not exist yet" do
    defp create_with(conn, query, name) do
      {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))
      send(live.pid, :update_sec)
      _ = render(live)
      html = render_submit(live, "add-to-new", %{"vision" => %{"name" => name}})
      Process.sleep(50)
      html
    end

    test "creates the vision and pins the query to it", ctx do
      q = query(ctx, "AAPL")

      create_with(ctx.conn, q, "Morning commute")

      vision =
        Configuration.list_visions()
        |> Enum.find(&(&1.name == "Morning commute"))

      assert vision
      assert vision.query_ids == [q.id]
      assert length(vision.queries) == 1
    end

    test "the query page then shows it", ctx do
      q = query(ctx, "AAPL")

      create_with(ctx.conn, q, "Morning commute")

      visions = Configuration.get_visions(:query, to_string(q.id))
      assert Enum.map(visions, & &1.name) == ["Morning commute"]
    end

    test "the form is offered even when there is nothing to add to", ctx do
      q = query(ctx, "AAPL")

      # the only vision already holds it, so the "add to" list is empty
      add(ctx.conn, q, ctx.vision)

      {:ok, live, _html} = live(conn_for(ctx), Routes.query_show_path(ctx.conn, :show, q))
      send(live.pid, :update_sec)
      _ = render(live)
      html = render_click(live, "toggle-sel", %{})

      assert html =~ ~s(phx-submit="add-to-new")
    end

    test "a blank name is refused rather than making an unnamed vision", ctx do
      q = query(ctx, "AAPL")
      before = length(Configuration.list_visions())

      html = create_with(ctx.conn, q, "   ")

      assert html =~ "Give the vision a name"
      assert length(Configuration.list_visions()) == before
    end

    test "the new vision belongs to the user who made it", ctx do
      q = query(ctx, "AAPL")

      create_with(ctx.conn, q, "Mine")

      vision = Configuration.list_visions() |> Enum.find(&(&1.name == "Mine"))
      assert vision.user_id == ctx.user.id
    end

    test "two new visions from the same query both hold it", ctx do
      q = query(ctx, "AAPL")

      create_with(ctx.conn, q, "One")
      create_with(ctx.conn, q, "Two")

      for name <- ["One", "Two"] do
        vision = Configuration.list_visions() |> Enum.find(&(&1.name == name))
        assert vision.query_ids == [q.id], "#{name} did not get the query"
      end
    end
  end

  describe "taking a query back out" do
    defp remove(conn, query, vision) do
      {:ok, live, _html} = live(conn, Routes.query_show_path(conn, :show, query))
      send(live.pid, :update_sec)
      _ = render(live)
      render_click(live, "remove-from", %{"vision" => to_string(vision.id)})
      Process.sleep(50)
      Configuration.get_vision!(vision.id)
    end

    test "drops the query from both halves", ctx do
      q = query(ctx, "AAPL")
      add(ctx.conn, q, ctx.vision)

      vision = remove(ctx.conn, q, ctx.vision)

      assert vision.query_ids == []
      assert vision.queries == []
    end

    test "the query page stops listing the vision", ctx do
      q = query(ctx, "AAPL")
      add(ctx.conn, q, ctx.vision)
      assert length(Configuration.get_visions(:query, to_string(q.id))) == 1

      remove(ctx.conn, q, ctx.vision)

      assert Configuration.get_visions(:query, to_string(q.id)) == []
    end

    test "the vision is offered again afterwards", ctx do
      q = query(ctx, "AAPL")
      add(ctx.conn, q, ctx.vision)
      assert Configuration.get_visions_nv(:query, to_string(q.id)) == []

      remove(ctx.conn, q, ctx.vision)

      assert length(Configuration.get_visions_nv(:query, to_string(q.id))) == 1
    end

    test "the other queries in that vision are left alone", ctx do
      a = query(ctx, "AAPL")
      b = query(ctx, "MSFT")
      add(ctx.conn, a, ctx.vision)
      add(ctx.conn, b, ctx.vision)

      vision = remove(ctx.conn, a, ctx.vision)

      assert vision.query_ids == [b.id]
      assert length(vision.queries) == 1
    end

    test "removing something already gone is not an error", ctx do
      q = query(ctx, "AAPL")

      vision = remove(ctx.conn, q, ctx.vision)

      assert vision.query_ids in [nil, []]
    end

    test "the button only appears while the panel is open", ctx do
      q = query(ctx, "AAPL")
      add(ctx.conn, q, ctx.vision)

      {:ok, live, _html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, q))
      send(live.pid, :update_sec)
      closed = render(live)
      refute closed =~ ~s(phx-click="remove-from")

      open = render_click(live, "toggle-sel", %{})
      assert open =~ ~s(phx-click="remove-from")
    end
  end

  defp conn_for(ctx), do: ctx.conn

  test "a third query still lands", ctx do
    queries = for symbol <- ~w(AAPL MSFT GOOG), do: query(ctx, symbol)

    vision = Enum.reduce(queries, ctx.vision, fn q, _acc -> add(ctx.conn, q, ctx.vision) end)

    assert vision.query_ids == Enum.map(queries, & &1.id)
    assert length(vision.queries) == 3
  end
end
