defmodule RoomSanctumWeb.PythiaeOwnedIdsTest do
  @moduledoc """
  A pythiae shows its owner's visions, at their foci or Plani, on their
  Ankyra. The form only offers those; a forged id of anyone else's is
  refused with a changeset error and nothing is saved.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest
  import RoomSanctum.DataCase, only: [errors_on: 1]
  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.{Configuration, Repo}
  alias RoomSanctum.Configuration.Pythiae

  setup :users_rabbit!

  setup %{conn: conn} do
    me = owner()
    %{conn: log_in_user(conn, me), me: me, them: owner()}
  end

  defp submit(conn, fields) do
    {:ok, live, _html} = live(conn, Routes.pythiae_index_path(conn, :new))

    live
    |> form("#pythiae-form")
    |> render_submit(%{"pythiae" => Map.put(fields, "name", "screen")})
  end

  defp ids(records), do: Enum.map(records, &to_string(&1.id))

  test "the form saves the owner's own visions, ankyra and foci", ctx do
    vision = vision_for(ctx.me)
    ankyra = ankyra_for(ctx.me)
    foci = foci_for(ctx.me)

    submit(ctx.conn, %{
      "visions" => ids([vision]),
      "ankyra" => ids([ankyra]),
      "curr_vision" => to_string(vision.id),
      "curr_foci" => to_string(foci.id)
    })

    assert [%Pythiae{} = saved] = Repo.all(Pythiae)
    assert saved.visions == [vision.id]
    assert saved.ankyra == [ankyra.id]
    assert saved.curr_foci == foci.id
  end

  test "the form refuses each of another user's records", ctx do
    vision = vision_for(ctx.me)
    ankyra = ankyra_for(ctx.me)

    own = %{
      "visions" => ids([vision]),
      "ankyra" => ids([ankyra]),
      "curr_vision" => to_string(vision.id)
    }

    forged = [
      %{"visions" => ids([vision, vision_for(ctx.them)])},
      %{"ankyra" => ids([ankyra, ankyra_for(ctx.them)])},
      %{"curr_vision" => to_string(vision_for(ctx.them).id)},
      %{"curr_foci" => to_string(foci_for(ctx.them).id)},
      %{"curr_plani" => to_string(plani_for(ctx.them).id)}
    ]

    for fields <- forged do
      submit(ctx.conn, Map.merge(own, fields))
      assert Repo.all(Pythiae) == [], "saved with #{inspect(fields)}"
    end
  end

  test "an existing pythiae cannot be moved onto another user's plani", ctx do
    {:ok, screen} =
      Configuration.create_pythiae(%{name: "screen", user_id: ctx.me.id, visions: [], ankyra: []})

    assert {:error, changeset} =
             Configuration.update_pythiae(screen, %{curr_plani: plani_for(ctx.them).id})

    assert %{curr_plani: [_]} = errors_on(changeset)
    assert {:ok, _} = Configuration.update_pythiae(screen, %{curr_plani: plani_for(ctx.me).id})
  end
end
