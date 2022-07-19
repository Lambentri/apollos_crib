defmodule RoomHermesWeb.RabbitUserView do
  use RoomHermesWeb, :view
  alias RoomHermesWeb.RabbitUserView

  def render("index.json", %{users_rabbit: users_rabbit}) do
    %{data: render_many(users_rabbit, RabbitUserView, "rabbit_user.json")}
  end

  def render("show.json", %{rabbit_user: rabbit_user}) do
    %{data: render_one(rabbit_user, RabbitUserView, "rabbit_user.json")}
  end

  def render("rabbit_user.json", %{rabbit_user: rabbit_user}) do
    %{
      id: rabbit_user.id,
      username: rabbit_user.username,
      password: rabbit_user.password
    }
  end
end
