defmodule RoomHermesWeb.RabbitUserControllerTest do
  use RoomHermesWeb.ConnCase

  import RoomHermes.AccountsFixtures

  alias RoomHermes.Accounts.RabbitUser

  @create_attrs %{
    password: "some password",
    username: "some username"
  }
  @update_attrs %{
    password: "some updated password",
    username: "some updated username"
  }
  @invalid_attrs %{password: nil, username: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all users_rabbit", %{conn: conn} do
      conn = get(conn, Routes.rabbit_user_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create rabbit_user" do
    test "renders rabbit_user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.rabbit_user_path(conn, :create), rabbit_user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.rabbit_user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "password" => "some password",
               "username" => "some username"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.rabbit_user_path(conn, :create), rabbit_user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update rabbit_user" do
    setup [:create_rabbit_user]

    test "renders rabbit_user when data is valid", %{conn: conn, rabbit_user: %RabbitUser{id: id} = rabbit_user} do
      conn = put(conn, Routes.rabbit_user_path(conn, :update, rabbit_user), rabbit_user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.rabbit_user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "password" => "some updated password",
               "username" => "some updated username"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, rabbit_user: rabbit_user} do
      conn = put(conn, Routes.rabbit_user_path(conn, :update, rabbit_user), rabbit_user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rabbit_user" do
    setup [:create_rabbit_user]

    test "deletes chosen rabbit_user", %{conn: conn, rabbit_user: rabbit_user} do
      conn = delete(conn, Routes.rabbit_user_path(conn, :delete, rabbit_user))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.rabbit_user_path(conn, :show, rabbit_user))
      end
    end
  end

  defp create_rabbit_user(_) do
    rabbit_user = rabbit_user_fixture()
    %{rabbit_user: rabbit_user}
  end
end
