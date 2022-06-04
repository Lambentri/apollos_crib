defmodule RoomSanctumWeb.PageController do
  use RoomSanctumWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
