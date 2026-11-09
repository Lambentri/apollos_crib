defmodule RoomSanctumWeb.PlaniOwnedIdsTest do
  @moduledoc """
  A Plani asks its owner's sources around wherever their client is, falling
  back to their foci. The form only offers those; a forged id of anyone
  else's is refused with a changeset error and nothing is saved.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest
  import RoomSanctum.DataCase, only: [errors_on: 1]
  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.{Configuration, Repo}
  alias RoomSanctum.Configuration.Plani

  setup :users_rabbit!

  setup %{conn: conn} do
    me = owner()
    %{conn: log_in_user(conn, me), me: me, them: owner()}
  end

  defp submit(conn, fields) do
    {:ok, live, _html} = live(conn, Routes.plani_index_path(conn, :new))

    live
    |> form("#plani-form")
    |> render_submit(%{"plani" => Map.put(fields, "name", "Pocket")})
  end

  defp mine(ctx) do
    foci = foci_for(ctx.me)

    %{
      "home_foci_id" => to_string(foci.id),
      "home_foci_ids" => [to_string(foci.id)],
      "ankyra_id" => to_string(ankyra_for(ctx.me).id),
      "sources" => [to_string(source_for(ctx.me).id)]
    }
  end

  test "the form saves the owner's own foci, ankyra and sources", ctx do
    own = mine(ctx)
    submit(ctx.conn, own)

    assert [%Plani{} = saved] = Repo.all(Plani)
    assert to_string(saved.ankyra_id) == own["ankyra_id"]
    assert Enum.map(saved.sources, &to_string/1) == own["sources"]
  end

  test "the form refuses each of another user's records", ctx do
    own = mine(ctx)
    their_foci = to_string(foci_for(ctx.them).id)

    forged = [
      %{"home_foci_id" => their_foci},
      %{"home_foci_ids" => own["home_foci_ids"] ++ [their_foci]},
      %{"ankyra_id" => to_string(ankyra_for(ctx.them).id)},
      %{"sources" => own["sources"] ++ [to_string(source_for(ctx.them).id)]}
    ]

    for fields <- forged do
      submit(ctx.conn, Map.merge(own, fields))
      assert Repo.all(Plani) == [], "saved with #{inspect(fields)}"
    end
  end

  test "an existing plani cannot be pointed at another user's source", ctx do
    plani = plani_for(ctx.me)

    assert {:error, changeset} =
             Configuration.update_plani(plani, %{sources: [source_for(ctx.them).id]})

    assert %{sources: [_]} = errors_on(changeset)
    assert {:ok, _} = Configuration.update_plani(plani, %{sources: [source_for(ctx.me).id]})
  end
end
