defmodule RoomSanctumWeb.OwnershipTest do
  @moduledoc """
  The /cfg pages only reach the signed-in user's own records. Another user's
  id -- in the URL, or in an event the client sends -- gets the same
  not-found a missing one does, and changes nothing.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration, Repo}

  defp user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "own#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    user
  end

  defp source_for(user, name \\ "Markets") do
    {:ok, source} =
      Configuration.create_source(%{
        name: name,
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    source
  end

  defp query_for(user) do
    source = source_for(user)

    {:ok, query} =
      Configuration.create_query(%{
        name: "Their query",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "SECRET"}
      })

    query
  end

  # A lookup that raises takes the LiveView down with it, as a missing id
  # always has; the test only cares that nothing was changed on the way.
  defp forge(live, event, params) do
    Process.flag(:trap_exit, true)
    catch_exit(render_click(live, event, params))
  end

  setup %{conn: conn} do
    me = user()
    %{conn: log_in_user(conn, me), me: me, them: user()}
  end

  describe "the query list" do
    test "will not open another user's query for editing", ctx do
      theirs = query_for(ctx.them)

      assert_raise Ecto.NoResultsError, fn ->
        live(ctx.conn, Routes.query_index_path(ctx.conn, :edit, theirs))
      end
    end

    test "will not delete another user's query", ctx do
      theirs = query_for(ctx.them)
      {:ok, live, _html} = live(ctx.conn, Routes.query_index_path(ctx.conn, :index))

      forge(live, "delete", %{"id" => to_string(theirs.id)})

      assert Repo.reload(theirs)
    end
  end
end
