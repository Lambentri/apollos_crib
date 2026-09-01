defmodule RoomSanctumWeb.VisionFormQueriesTest do
  @moduledoc """
  Editing the list of queries on a vision.

  The form's own buttons -- remove, add, change a type -- used to build their
  params from `form.params`, which is empty on a form nobody has typed into
  yet. `"queries" => %{}` tells cast_embed the form has no queries, and the
  embed replaces on delete, so removing one query removed all of them.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}
  alias RoomSanctum.Configuration.Vision

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "vform#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "T", notes: "", type: :gtfs, enabled: true, user_id: user.id,
        config: %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"}
      })

    queries =
      for name <- ~w(First Second Third) do
        {:ok, query} =
          Configuration.create_query(%{
            name: name, notes: "", source_id: source.id, user_id: user.id,
            query: %{"__type__" => "gtfs", "stop" => "s1"}
          })

        query
      end

    {:ok, vision} =
      Configuration.create_vision(%{
        name: "Commute",
        user_id: user.id,
        query_ids: Enum.map(queries, & &1.id),
        queries:
          queries
          |> Enum.with_index(1)
          |> Enum.map(fn {q, i} ->
            %{"type" => "pinned", "data" => %{"__type__" => "pinned", "query" => q.id, "order" => i}}
          end)
      })

    %{conn: log_in_user(conn, user), vision: vision, queries: queries, user: user, source: source}
  end

  defp spare_query(user, source, name) do
    {:ok, query} =
      Configuration.create_query(%{
        name: name, notes: "", source_id: source.id, user_id: user.id,
        query: %{"__type__" => "gtfs", "stop" => "s1"}
      })

    query
  end

  defp chosen_id(html, row) do
    html
    |> Floki.parse_document!()
    |> Floki.attribute(~s(input[name="vision[queries][#{row}][data][query]"]), "value")
    |> List.first()
  end

  defp box_text(html, row) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s([phx-keyup="query_search"][phx-value-index="#{row}"]))
    |> Floki.attribute("value")
    |> List.first()
  end

  defp offered(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s([phx-click="query_pick"] span.grow))
    |> Enum.map(&Floki.text/1)
  end

  defp query_rows(html) do
    html |> Floki.parse_document!() |> Floki.find(~s([name^="vision[queries]"][name$="[type]"])) |> length()
  end

  test "the form opens with every query on it", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

    assert query_rows(render(live)) == 3
  end

  test "removing one query removes one query", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

    # The reported bug: on a form nobody has typed into, this emptied the list.
    html = live |> element(~s([phx-click="remove_query"][phx-value-index="1"])) |> render_click()

    assert query_rows(html) == 2
  end

  test "removing them one at a time gets to none, a step at a time",
       %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

    for remaining <- [2, 1, 0] do
      html = live |> element(~s([phx-click="remove_query"][phx-value-index="0"])) |> render_click()
      assert query_rows(html) == remaining
    end
  end

  test "adding a query adds one to the ones already there", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

    html = live |> element(~s([phx-click="add_query"])) |> render_click()

    assert query_rows(html) == 4
  end

  describe "picking a query" do
    test "the box shows the query's name, not its id", %{conn: conn, vision: vision, queries: queries} do
      {:ok, _live, html} = live(conn, "/cfg/visions/#{vision.id}/edit")
      [first, second, third] = queries

      assert box_text(html, 0) == "First"
      assert box_text(html, 1) == "Second"
      assert box_text(html, 2) == "Third"

      # The id still rides along, because that is what the field holds.
      assert chosen_id(html, 0) == to_string(first.id)
      assert chosen_id(html, 1) == to_string(second.id)
      assert chosen_id(html, 2) == to_string(third.id)
    end

    test "typing filters this user's queries by name",
         %{conn: conn, vision: vision, user: user, source: source} do
      # A query not yet on the vision, so there is something to find.
      {:ok, _spare} =
        Configuration.create_query(%{
          name: "Second spare", notes: "", source_id: source.id, user_id: user.id,
          query: %{"__type__" => "gtfs", "stop" => "s1"}
        })

      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      html =
        live
        |> element(~s([phx-keyup="query_search"][phx-value-index="0"]))
        |> render_keyup(%{"value" => "sec"})

      assert offered(html) == ["Second spare"]
    end

    test "a search matching nothing says so rather than showing an empty list",
         %{conn: conn, vision: vision} do
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      html =
        live
        |> element(~s([phx-keyup="query_search"][phx-value-index="0"]))
        |> render_keyup(%{"value" => "zzz"})

      assert html =~ "No queries match"
    end

    test "picking one puts its id in the field and its name in the box",
         %{conn: conn, vision: vision, user: user, source: source} do
      third = spare_query(user, source, "Third spare")
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      live
      |> element(~s([phx-keyup="query_search"][phx-value-index="0"]))
      |> render_keyup(%{"value" => "spare"})

      html =
        live
        |> element(~s([phx-click="query_pick"][phx-value-index="0"][phx-value-id="#{third.id}"]))
        |> render_click()

      # Row 0 specifically -- the id it holds and the name it shows.
      assert chosen_id(html, 0) == to_string(third.id)
      assert box_text(html, 0) == "Third spare"
      # And the dropdown closes again.
      assert offered(html) == []
    end

    test "a query already on the vision is not offered to another row",
         %{conn: conn, vision: vision} do
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      # All three of this user's queries are already spoken for, one per row,
      # so searching from any row turns up nothing to move to.
      html =
        live
        |> element(~s([phx-keyup="query_search"][phx-value-index="0"]))
        |> render_keyup(%{"value" => "d"})

      assert offered(html) == []
    end

    test "a row still offers what it is already pointing at",
         %{conn: conn, vision: vision} do
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      # Row 2 holds "Third"; taking it out of its own list would leave the box
      # unable to show what it is set to.
      html =
        live
        |> element(~s([phx-keyup="query_search"][phx-value-index="2"]))
        |> render_keyup(%{"value" => "thi"})

      assert offered(html) == ["Third"]
    end

    test "freeing a query offers it to the other rows again",
         %{conn: conn, vision: vision} do
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      # Remove the row holding "Second" and it becomes available elsewhere.
      live |> element(~s([phx-click="remove_query"][phx-value-index="1"])) |> render_click()

      html =
        live
        |> element(~s([phx-keyup="query_search"][phx-value-index="0"]))
        |> render_keyup(%{"value" => "sec"})

      assert offered(html) == ["Second"]
    end

    test "a pick is what gets saved", %{conn: conn, vision: vision, user: user, source: source} do
      third = spare_query(user, source, "Third spare")
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      live
      |> element(~s([phx-keyup="query_search"][phx-value-index="0"]))
      |> render_keyup(%{"value" => "spare"})

      live
      |> element(~s([phx-click="query_pick"][phx-value-index="0"][phx-value-id="#{third.id}"]))
      |> render_click()

      live |> form("#vision-form", vision: %{name: "Commute"}) |> render_submit()

      assert [first | _] = Configuration.get_vision!(vision.id).queries
      assert first.data.query == third.id
    end

    test "picking on one row leaves the other rows alone",
         %{conn: conn, vision: vision, queries: queries, user: user, source: source} do
      [first, _second, third] = queries
      spare = spare_query(user, source, "Spare")
      {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

      live
      |> element(~s([phx-keyup="query_search"][phx-value-index="1"]))
      |> render_keyup(%{"value" => "spare"})

      live
      |> element(~s([phx-click="query_pick"][phx-value-index="1"][phx-value-id="#{spare.id}"]))
      |> render_click()

      live |> form("#vision-form", vision: %{name: "Commute"}) |> render_submit()

      assert [a, b, c] = Configuration.get_vision!(vision.id).queries
      assert a.data.query == first.id
      assert b.data.query == spare.id
      assert c.data.query == third.id
    end
  end

  test "a removal survives being saved", %{conn: conn, vision: vision} do
    {:ok, live, _html} = live(conn, "/cfg/visions/#{vision.id}/edit")

    live |> element(~s([phx-click="remove_query"][phx-value-index="1"])) |> render_click()

    live |> form("#vision-form", vision: %{name: "Commute"}) |> render_submit()

    assert %Vision{queries: [first, second]} = Configuration.get_vision!(vision.id)
    assert first.data.order == 1
    assert second.data.order == 3
  end
end
