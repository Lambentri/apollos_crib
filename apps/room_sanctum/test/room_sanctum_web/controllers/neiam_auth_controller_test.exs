defmodule RoomSanctumWeb.NeiamAuthControllerTest do
  @moduledoc """
  "Sign in with NEIAM" against neiam_auth's FakeIdP, through RoomSanctum's
  own router, session and (phx.gen.auth 1.7) UserAuth.
  """
  use RoomSanctumWeb.ConnCase, async: false
  # ConnCase doesn't bring in ~p.
  use RoomSanctumWeb, :verified_routes

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias NeiamAuth.Identity
  alias NeiamAuth.Test.FakeIdP
  alias RoomSanctum.{Accounts, Configuration, Repo}
  alias RoomSanctum.Accounts.User

  @password "hello world!hello world!"

  setup do
    # NeiamAuth is config held in a persistent_term; put back the app's own
    # (disabled) config after each test.
    on_exit(fn -> NeiamAuth.put_config(NeiamAuth.Config.load(%{})) end)
    :ok
  end

  defp user_fixture(email) do
    {:ok, user} = Accounts.register_user(%{email: email, password: @password})
    user
  end

  defp idp(opts \\ []) do
    idp = FakeIdP.start(Keyword.take(opts, [:client_id, :user]))
    on_exit(fn -> FakeIdP.stop(idp) end)
    idp
  end

  defp neiam_env(idp, extra \\ []) do
    FakeIdP.env(
      idp,
      nil,
      [
        redirect_uri: "http://localhost:4002/auth/oidc/neiam/callback",
        scopes: "openid profile email groups",
        groups_claim: "groups",
        trust_email: "true",
        label: "Sign in with NEIAM"
      ] ++ extra
    )
  end

  defp start_neiam(env, ready \\ ["neiam"]) do
    start_supervised!(
      {NeiamAuth,
       env: Map.put(env, "OIDC_ENABLED", "true"),
       name: :neiam_auth_test,
       backoff_min: 50,
       backoff_max: 200}
    )

    Enum.each(ready, &wait_ready/1)
  end

  defp wait_ready(id, tries \\ 100) do
    {:ok, p} = NeiamAuth.config(id)

    cond do
      NeiamAuth.ready?(p) ->
        :ok

      tries > 0 ->
        Process.sleep(20)
        wait_ready(id, tries - 1)

      true ->
        flunk("provider #{id} never loaded")
    end
  end

  # The browser's round trip: our login route, the IdP, our callback.
  defp sso(conn, idp, id, opts \\ []) do
    conn = get(conn, "/auth/oidc/#{id}/login", Keyword.get(opts, :query, %{}))
    params = FakeIdP.authorize(idp, redirected_to(conn, 302))
    params = Keyword.get(opts, :tamper, & &1).(params)
    conn |> recycle() |> get("/auth/oidc/#{Keyword.get(opts, :callback, id)}/callback", params)
  end

  # gen.auth 1.7: the session holds :user_token, and the lookup returns the
  # user itself (1.8 returns {user, authenticated_at}).
  defp signed_in_user(conn) do
    case get_session(conn, :user_token) do
      nil -> nil
      token -> Accounts.get_user_by_session_token(token)
    end
  end

  defp quietly(fun) do
    capture_log(fn -> send(self(), {:result, fun.()}) end)
    assert_received {:result, result}
    result
  end

  describe "OIDC_ENABLED off (the default)" do
    test "no button, the routes 404, health says disabled", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")
      refute html =~ "/auth/oidc/"

      assert get(build_conn(), "/auth/oidc/neiam/login").status == 404

      assert get(build_conn(), "/auth/oidc/neiam/callback", %{code: "x", state: "y"}).status ==
               404

      assert %{"enabled" => false} =
               build_conn() |> get("/auth/oidc/health") |> json_response(200)
    end

    test "configured providers stay off without the switch", %{conn: conn} do
      idp = idp()

      start_supervised!({NeiamAuth, env: neiam_env(idp), name: :neiam_auth_test})

      {:ok, _lv, html} = live(conn, ~p"/users/log_in")
      refute html =~ "Sign in with NEIAM"
      assert get(build_conn(), "/auth/oidc/neiam/login").status == 404
    end
  end

  describe "with NEIAM enabled" do
    setup do
      idp = idp()
      start_neiam(neiam_env(idp))
      %{idp: idp}
    end

    test "the log-in page shows the button as a plain link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")
      assert html =~ "Sign in with NEIAM"
      assert html =~ ~s(href="/auth/oidc/neiam/login")
    end

    test "first login links an existing account by verified email", %{conn: conn, idp: idp} do
      user = user_fixture("alice@example.com")

      conn = sso(conn, idp, "neiam")
      assert redirected_to(conn) == ~p"/"
      assert signed_in_user(conn).id == user.id
      # gen.auth 1.7's live_socket_id, so log-out still disconnects LiveViews.
      assert get_session(conn, :live_socket_id) =~ "users_sessions:"

      assert [%Identity{sub: "fake-sub-1", provider: "neiam", groups: ["users"]} = identity] =
               Repo.all(Identity)

      assert identity.user_id == user.id

      # LiveView pages behind :ensure_authenticated work on the new session.
      {:ok, _lv, _html} = conn |> recycle() |> live(~p"/users/settings")
    end

    test "the remember-me cookie is written, as for a ticked password login",
         %{conn: conn, idp: idp} do
      user_fixture("alice@example.com")
      conn = sso(conn, idp, "neiam")
      assert conn.resp_cookies["_room_sanctum_web_user_remember_me"]
    end

    test "an existing sub signs the same user in again", %{conn: conn, idp: idp} do
      user = user_fixture("alice@example.com")
      sso(conn, idp, "neiam")

      FakeIdP.put_user(idp, email: "alice.renamed@example.com")
      conn = sso(build_conn(), idp, "neiam")
      assert signed_in_user(conn).id == user.id
      assert [%Identity{email: "alice.renamed@example.com"}] = Repo.all(Identity)
    end

    test "the email match is case-insensitive (citext)", %{conn: conn, idp: idp} do
      user = user_fixture("Alice@Example.com")
      conn = sso(conn, idp, "neiam")
      assert signed_in_user(conn).id == user.id
    end

    test "return_to is honoured, and only local paths", %{conn: conn, idp: idp} do
      user_fixture("alice@example.com")
      conn = sso(conn, idp, "neiam", query: %{"return_to" => "/cfg/visions"})
      assert redirected_to(conn) == "/cfg/visions"

      conn = sso(build_conn(), idp, "neiam", query: %{"return_to" => "//evil.example/"})
      assert redirected_to(conn) == ~p"/"
    end

    test "a protected page's stored return path survives the round trip", %{idp: idp} do
      user_fixture("alice@example.com")

      # require_authenticated_user stores :user_return_to and sends us to log in.
      conn = get(build_conn(), "/cfg/visions")
      assert redirected_to(conn) == ~p"/users/log_in"

      conn = conn |> recycle() |> sso(idp, "neiam")
      assert redirected_to(conn) == "/cfg/visions"
    end

    test "state mismatch is refused", %{conn: conn, idp: idp} do
      user_fixture("alice@example.com")
      conn = quietly(fn -> sso(conn, idp, "neiam", tamper: &Map.put(&1, "state", "forged")) end)
      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Sign-in failed"
      refute signed_in_user(conn)
    end

    test "expired state is refused" do
      {:ok, p} = NeiamAuth.config("neiam")
      entry = %{"provider" => "neiam", "state" => "s", "at" => System.system_time(:second) - 601}

      assert {:error, :state_expired} =
               NeiamAuth.Flow.finish(p, %{"state" => "s", "code" => "c"}, entry)
    end

    test "invite-only (the default): no account means no sign-in", %{conn: conn, idp: idp} do
      conn = quietly(fn -> sso(conn, idp, "neiam") end)
      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invite"
      refute signed_in_user(conn)
      assert Repo.all(Identity) == []
      assert Repo.all(User) == []
    end

    test "password login still works for a linked account (Phase A)", %{conn: conn, idp: idp} do
      user = user_fixture("alice@example.com")
      sso(conn, idp, "neiam")
      assert [_] = Repo.all(Identity)

      conn =
        post(build_conn(), ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => @password}
        })

      assert signed_in_user(conn).id == user.id
    end

    test "a signed-in user links the account from settings", %{conn: conn, idp: idp} do
      FakeIdP.put_user(idp, email: "someone.else@example.com")
      user = user_fixture("alice@example.com")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/users/settings")
      assert html =~ ~s(href="/auth/oidc/neiam/login?link=1")

      conn = sso(conn, idp, "neiam", query: %{"link" => "1"})
      assert redirected_to(conn) == ~p"/users/settings"
      assert [%Identity{} = identity] = Repo.all(Identity)
      assert identity.user_id == user.id
    end

    test "health reports the provider ready", %{conn: conn} do
      # Through :browser, which accepts html only: probes send no Accept.
      conn = get(conn, "/auth/oidc/health")

      assert %{"enabled" => true, "providers" => [%{"id" => "neiam", "ready" => true}]} =
               json_response(conn, 200)
    end
  end

  describe "PROVISION=auto" do
    setup do
      idp = idp()
      start_neiam(neiam_env(idp, provision: "auto"))
      %{idp: idp}
    end

    test "creates a passwordless, confirmed user (hashed_password is nullable now)",
         %{conn: conn, idp: idp} do
      conn = sso(conn, idp, "neiam")
      user = signed_in_user(conn)
      assert user.email == "alice@example.com"
      assert user.hashed_password == nil
      assert %NaiveDateTime{} = user.confirmed_at

      # ... and no password gets that account in.
      refute Accounts.get_user_by_email_and_password("alice@example.com", "")
      refute Accounts.get_user_by_email_and_password("alice@example.com", @password)

      conn =
        post(build_conn(), ~p"/users/log_in", %{
          "user" => %{"email" => "alice@example.com", "password" => "anything at all"}
        })

      refute signed_in_user(conn)
    end
  end

  describe "the public pages stay public with SSO on" do
    setup do
      idp = idp()
      start_neiam(neiam_env(idp))

      owner = user_fixture("owner@example.com")
      {:ok, vision} = Configuration.create_vision(%{name: "Commute", user_id: owner.id})

      {:ok, pythiae} =
        Configuration.create_pythiae(%{
          name: "hallway-#{System.unique_integer([:positive])}",
          user_id: owner.id,
          ankyra: [],
          visions: [vision.id],
          curr_vision: vision.id
        })

      {:ok, scribus} =
        Configuration.create_scribus({:user, owner.id}, %{
          configuration: [],
          name: "kitchen",
          resolution: "800x480",
          vision: vision.id,
          enabled: true,
          color: :untouched,
          theme: :inky
        })

      %{pythiae: pythiae, scribus: scribus}
    end

    test "kiosk and board pages render signed out, with no redirect to log in",
         %{pythiae: pythiae, scribus: scribus} do
      paths = [
        # :public
        "/p/p/#{pythiae.name}",
        "/p/pl/#{pythiae.name}",
        "/p/s/c/#{scribus.id}",
        # :public_map
        "/p/m/#{pythiae.name}",
        # :public_inky
        "/p/s/i/#{scribus.id}",
        # :public_afterdark, :public_her
        "/p/s/a/#{scribus.id}",
        "/p/s/h/#{scribus.id}"
      ]

      for path <- paths do
        conn = get(build_conn(), path)
        assert conn.status == 200, "#{path} answered #{conn.status}"
        refute get_session(conn, :user_token), "#{path} signed someone in"
        refute get_session(conn, "neiam_auth"), "#{path} started an SSO flow"
      end
    end

    test "the public map mounts as a LiveView, signed out", %{pythiae: pythiae} do
      {:ok, _lv, html} = live(build_conn(), "/p/m/#{pythiae.name}")
      assert html =~ ~s(id="pythiae-map")
    end
  end

  describe "two providers (neiam trusted, google not)" do
    setup do
      neiam = idp()
      google = idp(client_id: "apollos-crib-at-google")

      google_env =
        FakeIdP.env(google, "google",
          redirect_uri: "http://localhost:4002/auth/oidc/google/callback",
          label: "Sign in with Google"
        )

      env =
        neiam
        |> FakeIdP.env("neiam",
          redirect_uri: "http://localhost:4002/auth/oidc/neiam/callback",
          groups_claim: "groups",
          trust_email: "true"
        )
        |> Map.merge(google_env)
        |> Map.put("OIDC_PROVIDERS", "neiam,google")

      start_neiam(env, ["neiam", "google"])
      %{neiam: neiam, google: google}
    end

    test "both buttons are shown", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")
      assert html =~ ~s(href="/auth/oidc/neiam/login")
      assert html =~ ~s(href="/auth/oidc/google/login")
    end

    test "an untrusted provider with the same email doesn't cross-link", %{
      conn: conn,
      google: google
    } do
      user_fixture("alice@example.com")
      conn = quietly(fn -> sso(conn, google, "google") end)
      refute signed_in_user(conn)
      assert Repo.all(Identity) == []
    end

    test "state started at one provider is refused at the other's callback",
         %{conn: conn, neiam: neiam} do
      user_fixture("alice@example.com")

      log =
        capture_log(fn -> send(self(), {:r, sso(conn, neiam, "neiam", callback: "google")}) end)

      assert_received {:r, conn}
      assert log =~ ":provider_mismatch"
      refute signed_in_user(conn)
    end

    test "the same sub at two issuers is two identities", %{
      conn: conn,
      neiam: neiam,
      google: google
    } do
      alice = user_fixture("alice@example.com")
      conn = sso(conn, neiam, "neiam")
      assert signed_in_user(conn).id == alice.id

      # Alice links Google from settings; the same sub there is a separate row.
      conn = sso(conn |> recycle(), google, "google", query: %{"link" => "1"})
      assert redirected_to(conn) == ~p"/users/settings"
      assert Repo.all(Identity) |> Enum.map(& &1.issuer) |> Enum.uniq() |> length() == 2
    end
  end

  test "an unreachable issuer: boot is fine and the button answers with a flash", %{conn: conn} do
    capture_log(fn ->
      start_supervised!(
        {NeiamAuth,
         env: %{
           "OIDC_ENABLED" => "true",
           "OIDC_ISSUER" => "http://127.0.0.1:1",
           "OIDC_CLIENT_ID" => "apollos-crib",
           "OIDC_CLIENT_SECRET" => "x",
           "OIDC_REDIRECT_URI" => "http://localhost:4002/auth/oidc/neiam/callback",
           "OIDC_ALLOW_UNSAFE_HTTP" => "true"
         },
         name: :neiam_auth_test,
         backoff_min: 50,
         backoff_max: 200}
      )

      {:ok, _lv, html} = live(conn, ~p"/users/log_in")
      assert html =~ "/auth/oidc/neiam/login"

      conn = get(build_conn(), "/auth/oidc/neiam/login")
      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't be reached"
    end)
  end
end
