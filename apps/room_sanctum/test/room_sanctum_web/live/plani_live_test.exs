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

  describe "the map" do
    alias RoomSanctumWeb.PlaniLive.Show

    test "centres on the anchor" do
      where = %{anchor: %Geo.Point{coordinates: {-71.1, 42.4}, srid: 4326}}

      assert Show.focus(where) == %{lat: 42.4, lng: -71.1}
    end

    test "has nothing to centre on before the worker has resolved one" do
      # Which the component reads as "fit whatever markers there are", the
      # right answer for a Plani that has not ticked yet.
      assert Show.focus(nil) == nil
      assert Show.focus(%{anchor: nil}) == nil
    end

    test "puts bikes on their own layer and everything else on the other" do
      where = %{
        places: [
          %{lat: 42.4, lon: -71.1, kind: :stop, name: "Davis", source_id: 1, source_name: "MBTA", tint: nil},
          %{lat: 42.5, lon: -71.2, kind: :bike, name: "b-1", source_id: 2, source_name: "Bluebikes", tint: nil},
          %{lat: 42.6, lon: -71.3, kind: :monitor, name: "Site", source_id: 3, source_name: "AirNow", tint: nil}
        ]
      }

      assert Enum.map(Show.markers(where, :bikes), & &1.name) == ["b-1"]
      assert Enum.map(Show.markers(where, :stations), & &1.name) == ["Davis", "Site"]
    end

    test "gives every marker a point the map can draw" do
      where = %{places: [%{lat: 42.4, lon: -71.1, kind: :stop, name: "Davis", source_id: 1, source_name: "MBTA", tint: nil}]}
      [marker] = Show.markers(where, :stations)

      # {lon, lat}, as everything geospatial in this app stores it.
      assert marker.place.coordinates == {-71.1, 42.4}
      assert marker.lat == 42.4
    end

    test "rings the radius around the anchor" do
      where = %{anchor: %Geo.Point{coordinates: {-71.1, 42.4}, srid: 4326}}

      [ring] = Show.radius_ring(where, 800)

      # Closed, so the line meets itself rather than leaving a gap.
      assert List.first(ring.points) == List.last(ring.points)

      lats = Enum.map(ring.points, &List.first/1)
      # 800m north and south of 42.4, near enough.
      assert_in_delta Enum.max(lats), 42.4072, 0.001
      assert_in_delta Enum.min(lats), 42.3928, 0.001
    end

    test "draws no ring before there is an anchor to draw it round" do
      assert Show.radius_ring(nil, 800) == []
      assert Show.radius_ring(%{anchor: nil}, 800) == []
    end

    test "draws nothing before the worker has found anything" do
      assert Show.markers(nil, :stations) == []
      assert Show.markers(%{anchor: nil}, :bikes) == []
    end
  end

  test "says when nothing is showing it", ctx do
    plani = plani(ctx)
    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ "No Pythiae is showing this"
  end

  test "links back to the Pythiae showing it", ctx do
    plani = plani(ctx)

    {:ok, pythiae} =
      Configuration.create_pythiae(%{
        name: "Kitchen",
        user_id: ctx.user.id,
        visions: [],
        ankyra: [],
        curr_plani: plani.id
      })

    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ "Showing on"
    assert html =~ pythiae.name
    refute html =~ "No Pythiae is showing this"
  end

  test "the preview says so before there is anything to preview", ctx do
    plani = plani(ctx)
    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ "What it is publishing"
    assert html =~ "asks its sources every half minute"
  end

  test "the map is on the page", ctx do
    plani = plani(ctx)
    {:ok, _live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    assert html =~ "plani-map"
    assert html =~ "What is around it"
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

  test "the preview switches between the Basic and Plus reads", ctx do
    plani = plani(ctx)
    {:ok, live, html} = live(ctx.conn, "/cfg/plani/#{plani.id}")

    # Basic is what the clients receive, so it is what the page opens on.
    assert html =~ "btn-primary"
    assert html =~ "Plus"

    plus = live |> element("button[phx-value-view=plus]") |> render_click()
    assert plus =~ "Plus"

    back = live |> element("button[phx-value-view=basic]") |> render_click()
    assert back =~ "Basic"
  end

  test "the bike limit is bounded", ctx do
    assert {:error, changeset} =
             Configuration.create_plani(%{
               name: "Too many",
               user_id: ctx.user.id,
               home_foci_id: ctx.foci.id,
               bike_limit: 500
             })

    assert changeset.errors[:bike_limit]
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
