defmodule RoomSanctumWeb.PlaniLiveTest do
  @moduledoc """
  The Plani pages render, which is the thing a compile cannot tell you.

  The worker is not running in a test, and both of the calls the show page
  makes fall back rather than raise when it is not — which is also what
  happens for the few seconds after a Plani is created, so it is worth having
  the page work in that state.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "plani#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home",
        place: %Geo.Point{coordinates: {-71.1, 42.4}, srid: 4326},
        user_id: user.id
      })

    %{conn: log_in_user(conn, user), user: user, foci: foci}
  end

  defp plani(ctx, attrs \\ %{}) do
    {:ok, plani} =
      Configuration.create_plani(
        Map.merge(
          %{name: "Pocket", user_id: ctx.user.id, home_foci_id: ctx.foci.id, sources: []},
          attrs
        )
      )

    plani
  end

  test "the index lists them", ctx do
    plani = plani(ctx)
    {:ok, _live, html} = live(ctx.conn, "/cfg/plani")

    assert html =~ "Plani"
    assert html =~ plani.name
  end

  test "the index says so when there are none", ctx do
    {:ok, _live, html} = live(ctx.conn, "/cfg/plani")
    assert html =~ "anchor moves"
  end

  defp source(ctx, name, attrs \\ %{}) do
    {:ok, source} =
      Configuration.create_source(
        Map.merge(
          %{name: name, type: :gtfs, config: %{}, enabled: true, user_id: ctx.user.id},
          attrs
        )
      )

    source
  end

  test "the show page renders before a worker exists", ctx do
    transit = source(ctx, "MBTA")
    plani = plani(ctx, %{sources: [transit.id]})

    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ plani.name
    # Nothing is running, so it says so rather than raising.
    assert html =~ "No worker yet"
    assert html =~ "MBTA"
  end

  test "following a tint picks up sources it was never told about", ctx do
    _named = source(ctx, "Named")
    _tinted = source(ctx, "Tinted", %{meta: %{tint: "teal"}})

    plani = plani(ctx, %{sources: [], follow_tint: "teal"})

    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ "Tinted"
    refute html =~ "Named"
    assert html =~ "following everything tinted"
  end

  test "a tint that is not a tint is refused", ctx do
    assert {:error, changeset} =
             Configuration.create_plani(%{
               name: "Puce",
               user_id: ctx.user.id,
               home_foci_id: ctx.foci.id,
               follow_tint: "puce"
             })

    assert changeset.errors[:follow_tint]
  end

  test "a Plani with no sources says what is missing", ctx do
    plani = plani(ctx)
    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ "No sources yet"
  end

  test "the radius and count are bounded", ctx do
    assert {:error, changeset} =
             Configuration.create_plani(%{
               name: "Too wide",
               user_id: ctx.user.id,
               home_foci_id: ctx.foci.id,
               radius: 50_000
             })

    assert changeset.errors[:radius]
  end
end
