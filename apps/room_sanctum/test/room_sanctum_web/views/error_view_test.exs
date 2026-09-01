defmodule RoomSanctumWeb.ErrorViewTest do
  use RoomSanctumWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(RoomSanctumWeb.ErrorView, "404.html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(RoomSanctumWeb.ErrorView, "500.html", []) == "Internal Server Error"
  end

  # The two above pass through Phoenix.View, which falls back to
  # template_not_found/2 -- so they passed while every real 404 answered 500.
  # The endpoint renders errors through Phoenix.Template, which does not, and
  # raised "no 404 html template defined" *while rendering the 404*. This one
  # goes the way a browser does.
  test "a missing page is answered 404, not 500", %{conn: conn} do
    conn = get(conn, "/no-such-page")

    assert conn.status == 404
    assert conn.resp_body =~ "Not Found"
  end
end
