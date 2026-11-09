defmodule RoomSanctumWeb.TintLabelShowTest do
  @moduledoc """
  The subgroup label on the pages that show a tint -- the page for one thing,
  and the list it is picked from.

  An offering's page has shown its tint since tints existed; a foci, a query
  and a vision each show theirs too, and a colour on its own no longer says
  which corner of itself something is in. The lists say the same thing, so a
  colour used for two subgroups can be told apart without opening a row.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  @sfo %Geo.Point{coordinates: {-122.38, 37.62}, srid: 4326}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "labels#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  # :bourse has an empty config and a one-field query, so the fixtures stay
  # about the label rather than about query shapes.
  defp offering(user, meta) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "Exchange",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"},
        meta: meta
      })

    source
  end

  defp asked(user, source, meta) do
    {:ok, query} =
      Configuration.create_query(%{
        name: "AAPL",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"},
        meta: meta
      })

    query
  end

  test "a foci says which subgroup of its tint it is in", ctx do
    {:ok, foci} =
      Configuration.create_foci(%{
        name: "SFO",
        user_id: ctx.user.id,
        place: @sfo,
        tint: "sky",
        tint_label: "airports"
      })

    {:ok, _live, html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :show, foci))

    # leading-4 with a -800 text colour is the inner badge's own class, so
    # this cannot pass on the word turning up somewhere else on the page.
    assert html =~ "text-sky-500"
    assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*airports/
  end

  test "a foci with a tint and no subgroup still just shows the dot", ctx do
    {:ok, foci} =
      Configuration.create_foci(%{name: "SFO", user_id: ctx.user.id, place: @sfo, tint: "sky"})

    {:ok, _live, html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :show, foci))

    assert html =~ "text-sky-500"
  end

  test "a query names its own subgroup and its offering's", ctx do
    # The two colours are stacked as two circles, so neither can carry a word
    # of its own -- both are spelled out beside them instead.
    source = offering(ctx.user, %{"tint" => "amber", "tint_label" => "markets"})
    query = asked(ctx.user, source, %{"tint" => "sky", "tint_label" => "watchlist"})

    {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, query))

    assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*watchlist/
    assert html =~ ~r/leading-4 text-amber-800[^>]*>\s*markets/
  end

  test "a query with an untinted offering names only its own subgroup", ctx do
    source = offering(ctx.user, %{})
    query = asked(ctx.user, source, %{"tint" => "sky", "tint_label" => "watchlist"})

    {:ok, _live, html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, query))

    assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*watchlist/

    # Nothing to say about an offering that wears no colour.
    refute html =~ "leading-4 text-amber-800"
  end

  test "a vision says which subgroup of its tint it is in", ctx do
    {:ok, vision} =
      Configuration.create_vision(%{
        name: "Morning",
        user_id: ctx.user.id,
        type: :time,
        public: false,
        meta: %{"tint" => "sky", "tint_label" => "commute"}
      })

    {:ok, _live, html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :show, vision))

    assert html =~ "text-sky-500"
    assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*commute/
  end

  describe "the lists they are picked from" do
    test "the foci list names each subgroup", ctx do
      {:ok, _} =
        Configuration.create_foci(%{
          name: "SFO",
          user_id: ctx.user.id,
          place: @sfo,
          tint: "sky",
          tint_label: "airports"
        })

      {:ok, _live, html} = live(ctx.conn, Routes.foci_index_path(ctx.conn, :index))

      assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*airports/
    end

    test "the offering list names each subgroup", ctx do
      offering(ctx.user, %{"tint" => "amber", "tint_label" => "markets"})

      {:ok, _live, html} = live(ctx.conn, Routes.source_index_path(ctx.conn, :index))

      assert html =~ ~r/leading-4 text-amber-800[^>]*>\s*markets/
    end

    test "the query list names the query's subgroup and its offering's", ctx do
      source = offering(ctx.user, %{"tint" => "amber", "tint_label" => "markets"})
      asked(ctx.user, source, %{"tint" => "sky", "tint_label" => "watchlist"})

      {:ok, _live, html} = live(ctx.conn, Routes.query_index_path(ctx.conn, :index))

      assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*watchlist/
      assert html =~ ~r/leading-4 text-amber-800[^>]*>\s*markets/
    end

    test "the vision list names each subgroup", ctx do
      {:ok, _} =
        Configuration.create_vision(%{
          name: "Morning",
          user_id: ctx.user.id,
          type: :time,
          public: false,
          meta: %{"tint" => "sky", "tint_label" => "commute"}
        })

      {:ok, _live, html} = live(ctx.conn, Routes.vision_index_path(ctx.conn, :index))

      assert html =~ ~r/leading-4 text-sky-800[^>]*>\s*commute/
    end

    test "a row with a tint and no subgroup is still just a dot", ctx do
      offering(ctx.user, %{"tint" => "amber"})

      {:ok, _live, html} = live(ctx.conn, Routes.source_index_path(ctx.conn, :index))

      assert html =~ "text-amber-500"

      # Not a bare colour class: the filter chips above the table carry one as
      # a hover colour, and bg-100/text-800 is a pill idiom used elsewhere. The
      # inner badge's leading-4 is what says a subgroup was rendered.
      refute html =~ "leading-4 text-amber-800"
    end
  end
end
