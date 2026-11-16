defmodule RoomSanctumWeb.UserSessionController do
  use RoomSanctumWeb, :controller

  alias RoomSanctum.Accounts
  alias RoomSanctumWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    user = Accounts.get_user_by_email_and_password(email, password)

    # No re-auth exception here (unlike gen.auth 1.8): this route sits behind
    # redirect_if_user_is_authenticated, and a password change has already
    # revoked the session by the time its form posts here, so every request
    # that reaches this is a sign-in.
    cond do
      # Only after the password checked out, so this says nothing about an
      # address to someone who doesn't know its password.
      user && not NeiamAuth.password_login_allowed?(user) ->
        sso_required(conn)

      user ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      true ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Invalid email or password")
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/users/log_in")
    end
  end

  defp sso_required(conn) do
    conn
    |> put_flash(:error, "This account signs in with NEIAM: use the Sign in with NEIAM button.")
    |> redirect(to: ~p"/users/log_in")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
