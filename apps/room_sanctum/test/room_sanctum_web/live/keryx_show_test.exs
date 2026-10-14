defmodule RoomSanctumWeb.KeryxShowTest do
  @moduledoc """
  The Keryx page: its topics, and whatever its worker has seen so far.

  Builds its own fixtures, as SourceLiveBulkPaintTest does, since
  ConfigurationFixtures predates the required user_id.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "herald#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Markets",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      })

    {:ok, query} =
      Configuration.create_query(%{
        name: "AAPL",
        notes: "",
        source_id: source.id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    {:ok, keryx} =
      Configuration.create_keryx(%{
        name: "herald",
        ttl: 60,
        query_ids: [query.id],
        user_id: user.id
      })

    %{conn: log_in_user(conn, user), keryx: keryx, query: query}
  end

  test "shows the topics a client subscribes to", %{conn: conn, keryx: keryx, query: query} do
    {:ok, _live, html} = live(conn, "/cfg/keryxiae/#{keryx.id}")

    assert html =~ "apollos/keryx/#{keryx.id}/control"
    assert html =~ "apollos/keryx/#{keryx.id}/bourse/#{query.id}"
  end

  # The page asks the Keryx's item cache what it has seen. That cache is a
  # process, and a process may not be there -- not started yet, or restarting
  # after its worker fell over -- which is an exit, not an exception.
  test "renders with no worker running", %{conn: conn, keryx: keryx} do
    assert {:ok, live, _html} = live(conn, "/cfg/keryxiae/#{keryx.id}")

    send(live.pid, :refresh_cache)
    assert render(live) =~ "herald"
  end
end

defmodule RoomSanctumWeb.KeryxItemPreviewTest do
  @moduledoc """
  The highlighted JSON beside each item the Keryx has seen.

  Dev rarely has any items, prod always does -- so a preview that cannot
  render takes the whole page down only where somebody is looking at it.
  """
  use ExUnit.Case, async: true

  alias RoomSanctumWeb.KeryxLive.Show

  test "highlights an item as JSON" do
    html = %{"route" => "14", "times" => ["08:00:00"]} |> Show.format_item_preview() |> Phoenix.HTML.safe_to_string()

    assert html =~ "route"
    assert html =~ "08:00:00"
  end

  test "falls back to inspect for what JSON cannot say" do
    assert Show.format_item_preview(%{at: {1, 2}}) =~ "{1, 2}"
  end

  test "falls back for an encoder that raises rather than being missing" do
    unloaded = %Ecto.Association.NotLoaded{__field__: :trip, __owner__: Trip, __cardinality__: :one}

    assert Show.format_item_preview(%{trip: unloaded}) =~ "NotLoaded"
  end
end
