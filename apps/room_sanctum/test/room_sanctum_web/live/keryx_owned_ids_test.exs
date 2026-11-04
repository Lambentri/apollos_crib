defmodule RoomSanctumWeb.KeryxOwnedIdsTest do
  @moduledoc """
  A keryx publishes its queries' results to whoever subscribes to it, so it
  may only carry its owner's queries. The form only offers those, but sends
  them as hidden inputs, and a forged one is refused.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest
  import RoomSanctum.DataCase, only: [errors_on: 1]
  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.{Configuration, Repo}
  alias RoomSanctum.Configuration.Keryx

  setup %{conn: conn} do
    me = owner()
    %{conn: log_in_user(conn, me), me: me}
  end

  defp submit(conn, query_ids) do
    {:ok, live, _html} = live(conn, Routes.keryx_index_path(conn, :new))

    live
    |> form("#keryx-form")
    |> render_submit(%{
      "keryx" => %{
        "name" => "herald",
        "ttl" => "60",
        "query_ids" => Enum.map(query_ids, &to_string/1)
      }
    })
  end

  test "the form saves the owner's own queries", ctx do
    mine = query_for(ctx.me)
    submit(ctx.conn, [mine.id])

    assert [%Keryx{query_ids: [id]}] = Repo.all(Keryx)
    assert id == mine.id
  end

  test "the form refuses another user's query", ctx do
    theirs = query_for(owner())
    submit(ctx.conn, [query_for(ctx.me).id, theirs.id])

    assert Repo.all(Keryx) == []
  end

  test "an existing keryx cannot be given another user's query", ctx do
    mine = query_for(ctx.me)

    {:ok, keryx} =
      Configuration.create_keryx(%{
        name: "herald",
        ttl: 60,
        query_ids: [mine.id],
        user_id: ctx.me.id
      })

    assert {:error, changeset} =
             Configuration.update_keryx(keryx, %{query_ids: [mine.id, query_for(owner()).id]})

    assert %{query_ids: [_]} = errors_on(changeset)
    assert {:ok, _} = Configuration.update_keryx(keryx, %{name: "renamed"})
  end
end
