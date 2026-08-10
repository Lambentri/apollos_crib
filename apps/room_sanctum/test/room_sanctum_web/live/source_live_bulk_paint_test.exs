defmodule RoomSanctumWeb.SourceLiveBulkPaintTest do
  @moduledoc """
  The bulk paint view on an offering: one row per query, a radio per tint,
  written through to the database as each radio is clicked.

  Builds its own source and queries rather than using ConfigurationFixtures,
  whose source_fixture/query_fixture predate the required user_id.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  # ConnCase.register_and_log_in_user/1 reaches for RoomSanctum.AccountsFixtures,
  # which does not exist in this tree, so the user is registered here instead.
  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "painter#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  setup %{user: user} do
    # :bourse has an empty source config and a one-field query, so the
    # fixtures stay about painting rather than about query shapes.
    {:ok, source} =
      Configuration.create_source(%{
        name: "Markets",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    queries =
      for symbol <- ~w(AAPL MSFT GOOG) do
        {:ok, query} =
          Configuration.create_query(%{
            name: symbol,
            notes: "note for #{symbol}",
            source_id: source.id,
            user_id: user.id,
            query: %{"__type__" => "bourse", "symbol" => symbol}
          })

        query
      end

    %{source: source, queries: queries}
  end

  defp tint_of(query_id) do
    query = Configuration.get_query!(query_id)
    query.meta && query.meta.tint
  end

  describe "entering the view" do
    test "the button is offered alongside the map view toggle", %{conn: conn, source: source} do
      {:ok, _live, html} = live(conn, Routes.source_show_path(conn, :show, source))

      assert html =~ "Bulk Paint"
      assert html =~ "Map View"
    end

    test "clicking it lists every query for the source", %{
      conn: conn,
      source: source,
      queries: queries
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))

      html = live |> element("button", "Bulk Paint") |> render_click()

      for query <- queries do
        assert html =~ query.name
      end
    end

    test "each query gets its own radio group, one radio per tint plus none", %{
      conn: conn,
      source: source,
      queries: queries
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      html = render(live)

      for query <- queries do
        radios = Regex.scan(~r/name="tint-#{query.id}"/, html) |> length()

        # nine tints in the palette, plus the "no tint" option
        assert radios == 10, "query #{query.id} rendered #{radios} radios"
      end
    end

    test "the toggle is a toggle -- clicking twice returns to the query list", %{
      conn: conn,
      source: source
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))

      assert live |> element("button", "Bulk Paint") |> render_click() =~ "Changes save as you click"
      refute live |> element("button", "Bulk Paint") |> render_click() =~ "Changes save as you click"
    end
  end

  describe "painting" do
    test "clicking a tint persists it to that query only", %{
      conn: conn,
      source: source,
      queries: [first, second, third]
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      live
      |> element(~s{input[name="tint-#{first.id}"][value="sky"]})
      |> render_click()

      assert tint_of(first.id) == "sky"
      assert tint_of(second.id) == nil
      assert tint_of(third.id) == nil
    end

    test "a whole pass over the list is retained", %{
      conn: conn,
      source: source,
      queries: [a, b, c]
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      for {query, tint} <- [{a, "amber"}, {b, "lime"}, {c, "fuchsia"}] do
        live
        |> element(~s{input[name="tint-#{query.id}"][value="#{tint}"]})
        |> render_click()
      end

      assert tint_of(a.id) == "amber"
      assert tint_of(b.id) == "lime"
      assert tint_of(c.id) == "fuchsia"
    end

    test "repainting replaces rather than stacks", %{conn: conn, source: source, queries: [q | _]} do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      live |> element(~s{input[name="tint-#{q.id}"][value="rose"]}) |> render_click()
      assert tint_of(q.id) == "rose"

      live |> element(~s{input[name="tint-#{q.id}"][value="violet"]}) |> render_click()
      assert tint_of(q.id) == "violet"
    end

    test "the none radio clears a tint", %{conn: conn, source: source, queries: [q | _]} do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      live |> element(~s{input[name="tint-#{q.id}"][value="emerald"]}) |> render_click()
      assert tint_of(q.id) == "emerald"

      live |> element(~s{input[name="tint-#{q.id}"][value=""]}) |> render_click()
      assert tint_of(q.id) == nil
    end

    test "the chosen radio comes back checked", %{conn: conn, source: source, queries: [q | _]} do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      html = live |> element(~s{input[name="tint-#{q.id}"][value="slate"]}) |> render_click()

      assert html =~ ~r/name="tint-#{q.id}"[^>]*value="slate"[^>]*checked/ or
               html =~ ~r/value="slate"[^>]*name="tint-#{q.id}"[^>]*checked/ or
               live
               |> element(~s{input[name="tint-#{q.id}"][value="slate"][checked]})
               |> has_element?()
    end

    test "the painted query keeps its own query embed intact", %{
      conn: conn,
      source: source,
      queries: [q | _]
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()

      live |> element(~s{input[name="tint-#{q.id}"][value="stone"]}) |> render_click()

      reloaded = Configuration.get_query!(q.id)
      assert reloaded.query.symbol == "AAPL"
      assert reloaded.name == "AAPL"
    end

    test "a painted tint becomes available as a filter", %{
      conn: conn,
      source: source,
      queries: [q | _]
    } do
      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))
      live |> element("button", "Bulk Paint") |> render_click()
      live |> element(~s{input[name="tint-#{q.id}"][value="sky"]}) |> render_click()

      # back to the query list, where available tints render as filter dots
      html = live |> element("button", "Bulk Paint") |> render_click()
      assert html =~ "text-sky-500"
    end
  end

  describe "empty source" do
    test "says so rather than rendering an empty table", %{conn: conn, user: user} do
      {:ok, empty} =
        Configuration.create_source(%{
          name: "No queries",
          notes: "",
          type: :bourse,
          enabled: true,
          user_id: user.id,
          config: %{"__type__" => "bourse"}
        })

      {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, empty))
      html = live |> element("button", "Bulk Paint") |> render_click()

      assert html =~ "no queries yet"
    end
  end
end
