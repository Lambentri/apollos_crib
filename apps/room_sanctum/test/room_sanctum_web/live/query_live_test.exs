defmodule RoomSanctumWeb.QueryLiveTest do
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest
  import RoomSanctum.ConfigurationFixtures

  @create_attrs %{name: "some name", notes: "some notes", query: %{}}
  @update_attrs %{name: "some updated name", notes: "some updated notes", query: %{}}
  @invalid_attrs %{name: nil, notes: nil, query: nil}

  defp create_query(_) do
    query = query_fixture()
    %{query: query}
  end

  describe "Index" do
    setup [:create_query]

    test "lists all cfg_queries", %{conn: conn, query: query} do
      {:ok, _index_live, html} = live(conn, Routes.query_index_path(conn, :index))

      assert html =~ "Listing Cfg queries"
      assert html =~ query.name
    end

    test "saves new query", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.query_index_path(conn, :index))

      assert index_live |> element("a", "New Query") |> render_click() =~
               "New Query"

      assert_patch(index_live, Routes.query_index_path(conn, :new))

      assert index_live
             |> form("#query-form", query: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#query-form", query: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.query_index_path(conn, :index))

      assert html =~ "Query created successfully"
      assert html =~ "some name"
    end

    test "updates query in listing", %{conn: conn, query: query} do
      {:ok, index_live, _html} = live(conn, Routes.query_index_path(conn, :index))

      assert index_live |> element("#query-#{query.id} a", "Edit") |> render_click() =~
               "Edit Query"

      assert_patch(index_live, Routes.query_index_path(conn, :edit, query))

      assert index_live
             |> form("#query-form", query: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#query-form", query: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.query_index_path(conn, :index))

      assert html =~ "Query updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes query in listing", %{conn: conn, query: query} do
      {:ok, index_live, _html} = live(conn, Routes.query_index_path(conn, :index))

      assert index_live |> element("#query-#{query.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#query-#{query.id}")
    end
  end

  describe "Show" do
    setup [:create_query]

    test "displays query", %{conn: conn, query: query} do
      {:ok, _show_live, html} = live(conn, Routes.query_show_path(conn, :show, query))

      assert html =~ "Show Query"
      assert html =~ query.name
    end

    test "updates query within modal", %{conn: conn, query: query} do
      {:ok, show_live, _html} = live(conn, Routes.query_show_path(conn, :show, query))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Query"

      assert_patch(show_live, Routes.query_show_path(conn, :edit, query))

      assert show_live
             |> form("#query-form", query: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#query-form", query: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.query_show_path(conn, :show, query))

      assert html =~ "Query updated successfully"
      assert html =~ "some updated name"
    end
  end
end
