defmodule RoomSanctum.UserLiveAuth do
  import Phoenix.LiveView
  import Phoenix.Component
  alias RoomSanctum.Accounts

  def on_mount(:default, _params, session, socket) do
    socket =
      assign_new(
        socket,
        :current_user,
        fn -> Accounts.get_user_by_session_token(session["user_token"]) end
      )

    if socket.assigns.current_user == nil do
      {:halt, redirect(socket, to: "/users/log_in")}
    else
      {:cont, socket}
    end
  end
end

defmodule RoomSanctum.UserLiveCanAuth do
  import Phoenix.LiveView
  import Phoenix.Component
  alias RoomSanctum.Accounts

  def on_mount(:default, _params, session, socket) do
    case session["user_token"] do
      nil ->
        socket = assign_new(socket, :current_user, fn -> nil end)
        {:cont, socket}

      _val ->
        socket =
          assign_new(
            socket,
            :current_user,
            fn -> Accounts.get_user_by_session_token(session["user_token"]) end
          )

        {:cont, socket}
    end
  end
end
