defmodule RoomSanctumWeb.KeryxLiveTest do
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest
  import RoomSanctum.ConfigurationFixtures

  @create_attrs %{name: "some name", ttl: 42, queries: [1, 2]}
  @update_attrs %{name: "some updated name", ttl: 43, queries: [1]}
  @invalid_attrs %{name: nil, ttl: nil, queries: []}

  defp create_keryx(_) do
    keryx = keryx_fixture()
    %{keryx: keryx}
  end

  describe "Index" do
    setup [:create_keryx]

    test "lists all keryxiae", %{conn: conn, keryx: keryx} do
      {:ok, _index_live, html} = live(conn, ~p"/keryxiae")

      assert html =~ "Listing Keryxiae"
      assert html =~ keryx.name
    end

    test "saves new keryx", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/keryxiae")

      assert index_live |> element("a", "New Keryx") |> render_click() =~
               "New Keryx"

      assert_patch(index_live, ~p"/keryxiae/new")

      assert index_live
             |> form("#keryx-form", keryx: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#keryx-form", keryx: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/keryxiae")

      html = render(index_live)
      assert html =~ "Keryx created successfully"
      assert html =~ "some name"
    end

    test "updates keryx in listing", %{conn: conn, keryx: keryx} do
      {:ok, index_live, _html} = live(conn, ~p"/keryxiae")

      assert index_live |> element("#keryxiae-#{keryx.id} a", "Edit") |> render_click() =~
               "Edit Keryx"

      assert_patch(index_live, ~p"/keryxiae/#{keryx}/edit")

      assert index_live
             |> form("#keryx-form", keryx: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#keryx-form", keryx: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/keryxiae")

      html = render(index_live)
      assert html =~ "Keryx updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes keryx in listing", %{conn: conn, keryx: keryx} do
      {:ok, index_live, _html} = live(conn, ~p"/keryxiae")

      assert index_live |> element("#keryxiae-#{keryx.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#keryxiae-#{keryx.id}")
    end
  end

  describe "Show" do
    setup [:create_keryx]

    test "displays keryx", %{conn: conn, keryx: keryx} do
      {:ok, _show_live, html} = live(conn, ~p"/keryxiae/#{keryx}")

      assert html =~ "Show Keryx"
      assert html =~ keryx.name
    end

    test "updates keryx within modal", %{conn: conn, keryx: keryx} do
      {:ok, show_live, _html} = live(conn, ~p"/keryxiae/#{keryx}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Keryx"

      assert_patch(show_live, ~p"/keryxiae/#{keryx}/show/edit")

      assert show_live
             |> form("#keryx-form", keryx: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#keryx-form", keryx: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/keryxiae/#{keryx}")

      html = render(show_live)
      assert html =~ "Keryx updated successfully"
      assert html =~ "some updated name"
    end
  end
end
