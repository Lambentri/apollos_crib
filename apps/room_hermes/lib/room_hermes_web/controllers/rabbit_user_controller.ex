defmodule RoomHermesWeb.RabbitUserController do
  use RoomHermesWeb, :controller

  alias RoomHermes.Accounts
  alias RoomHermes.Accounts.RabbitUser

  action_fallback RoomHermesWeb.FallbackController

  def index(conn, _params) do
    users_rabbit = Accounts.list_users_rabbit()
    render(conn, "index.json", users_rabbit: users_rabbit)
  end

  def create(conn, %{"rabbit_user" => rabbit_user_params}) do
    with {:ok, %RabbitUser{} = rabbit_user} <- Accounts.create_rabbit_user(rabbit_user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.rabbit_user_path(conn, :show, rabbit_user))
      |> render("show.json", rabbit_user: rabbit_user)
    end
  end

  def show(conn, %{"id" => id}) do
    rabbit_user = Accounts.get_rabbit_user!(id)
    render(conn, "show.json", rabbit_user: rabbit_user)
  end

  def update(conn, %{"id" => id, "rabbit_user" => rabbit_user_params}) do
    rabbit_user = Accounts.get_rabbit_user!(id)

    with {:ok, %RabbitUser{} = rabbit_user} <-
           Accounts.update_rabbit_user(rabbit_user, rabbit_user_params) do
      render(conn, "show.json", rabbit_user: rabbit_user)
    end
  end

  def delete(conn, %{"id" => id}) do
    rabbit_user = Accounts.get_rabbit_user!(id)

    with {:ok, %RabbitUser{}} <- Accounts.delete_rabbit_user(rabbit_user) do
      send_resp(conn, :no_content, "")
    end
  end
end
