defmodule RoomSanctumWeb.FociQuickAddTest do
  @moduledoc """
  Adding a "this source, at this place" query from the offering page.

  A stop-based source gets this from the map, and a ticker from the Control
  box; a foci-based one had nothing, so a weather query meant going to the
  query form and picking the source back out of a list.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "foci#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, home} =
      Configuration.create_foci(%{
        name: "Home", user_id: user.id,
        place: %Geo.Point{coordinates: {-71.0589, 42.3601}, srid: 4326}
      })

    %{conn: log_in_user(conn, user), user: user, home: home}
  end

  defp source(ctx, type, config) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "#{type}", notes: "", type: type, enabled: true,
        user_id: ctx.user.id, config: config
      })

    source
  end

  defp add_from(ctx, source) do
    {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, source))
    render_click(live, "toggle-foci-add", %{})
    render_change(live, "foci-pick", %{"foci" => %{"id" => to_string(ctx.home.id)}})
    render_click(live, "foci-add", %{})
    Configuration.get_queries(:source, source.id)
  end

  describe "the picker" do
    test "is offered for a source whose query is a place", ctx do
      src = source(ctx, :ephem, %{"__type__" => "ephem"})

      {:ok, live, html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))

      # tucked behind the + in the Queries card, like the tester is
      assert html =~ ~s(phx-click="toggle-foci-add")
      refute html =~ ~s(phx-click="foci-add")

      opened = render_click(live, "toggle-foci-add", %{})
      assert opened =~ ~s(phx-click="foci-add")
      assert opened =~ "Home"
    end

    test "the + closes again", ctx do
      src = source(ctx, :ephem, %{"__type__" => "ephem"})

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))

      assert render_click(live, "toggle-foci-add", %{}) =~ ~s(phx-click="foci-add")
      refute render_click(live, "toggle-foci-add", %{}) =~ ~s(phx-click="foci-add")
    end

    test "adding one closes the panel", ctx do
      src = source(ctx, :ephem, %{"__type__" => "ephem"})

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))
      render_click(live, "toggle-foci-add", %{})
      render_change(live, "foci-pick", %{"foci" => %{"id" => to_string(ctx.home.id)}})
      html = render_click(live, "foci-add", %{})

      refute html =~ ~s(phx-click="foci-add")
    end

    test "is not offered where a foci means nothing", ctx do
      src = source(ctx, :bourse, %{"__type__" => "bourse"})

      {:ok, _live, html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))

      refute html =~ ~s(phx-click="foci-add")
    end

    test "says so when there are no foci to pick", ctx do
      {:ok, other} =
        Accounts.register_user(%{
          email: "nofoci#{System.unique_integer([:positive])}@example.com",
          password: "hello world!hello world!"
        })

      {:ok, src} =
        Configuration.create_source(%{
          name: "ephem", notes: "", type: :ephem, enabled: true,
          user_id: other.id, config: %{"__type__" => "ephem"}
        })

      {:ok, live, _html} =
        live(log_in_user(build_conn(), other), Routes.source_show_path(build_conn(), :show, src))

      assert render_click(live, "toggle-foci-add", %{}) =~ "No foci yet"
    end
  end

  describe "adding" do
    test "a foci alone is enough for weather", ctx do
      src = source(ctx, :weather, %{"__type__" => "weather", "api_key" => "k", "units" => "metric"})

      assert [query] = add_from(ctx, src)
      assert query.query.foci_id == ctx.home.id
      assert query.name == "Weather at Home"
    end

    test "and for ephem, pollen and aqi", ctx do
      for {type, config} <- [
            {:ephem, %{"__type__" => "ephem"}},
            {:pollen, %{"__type__" => "pollen", "api_key" => "k"}},
            {:aqi, %{"__type__" => "aqi"}}
          ] do
        src = source(ctx, type, config)

        assert [query] = add_from(ctx, src), "#{type} added nothing"
        assert query.query.foci_id == ctx.home.id, "#{type} lost the foci"
      end
    end

    test "a calendar query gets workable display bounds", ctx do
      src = source(ctx, :calendar, %{"__type__" => "calendar", "url" => "https://e.test/c.ics"})

      assert [query] = add_from(ctx, src)
      # days and limit are required, so a query without them could not be saved
      assert query.query.days == 7
      assert query.query.limit == 10
    end

    # An icarus query cannot be created from this app's tests: its changeset
    # validates against RoomIcarus.Classify, which is not loadable here. The
    # shape it builds is covered by foci_query_for/2 below.
    test "an icarus query is built as an area query, which is what a foci means" do
      assert RoomSanctumWeb.SourceLive.Show.foci_query_preview(:icarus, 7) ==
               %{"__type__" => "icarus", "foci_id" => 7, "mode" => "area", "dist" => 25}
    end

    test "nothing is added without picking a foci", ctx do
      src = source(ctx, :ephem, %{"__type__" => "ephem"})

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))
      render_click(live, "toggle-foci-add", %{})
      html = render_click(live, "foci-add", %{})

      assert html =~ "Pick a foci first"
      assert Configuration.get_queries(:source, src.id) == []
    end

    test "the new query shows up in the source's list straight away", ctx do
      src = source(ctx, :ephem, %{"__type__" => "ephem"})

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))
      render_click(live, "toggle-foci-add", %{})
      render_change(live, "foci-pick", %{"foci" => %{"id" => to_string(ctx.home.id)}})
      html = render_click(live, "foci-add", %{})

      assert html =~ "Ephem at Home"
    end

    test "two foci give two queries", ctx do
      {:ok, work} =
        Configuration.create_foci(%{
          name: "Work", user_id: ctx.user.id,
          place: %Geo.Point{coordinates: {-71.09, 42.36}, srid: 4326}
        })

      src = source(ctx, :ephem, %{"__type__" => "ephem"})

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))

      for foci <- [ctx.home, work] do
        render_click(live, "toggle-foci-add", %{})
        render_change(live, "foci-pick", %{"foci" => %{"id" => to_string(foci.id)}})
        render_click(live, "foci-add", %{})
      end

      names = Configuration.get_queries(:source, src.id) |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["Ephem at Home", "Ephem at Work"]
    end
  end
end
