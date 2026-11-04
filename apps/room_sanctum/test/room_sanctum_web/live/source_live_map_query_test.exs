defmodule RoomSanctumWeb.SourceLiveMapQueryTest do
  @moduledoc """
  Making a query from a marker on the source page's map: the flash says
  whether one was made.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  # ConnCase.register_and_log_in_user/1 reaches for RoomSanctum.AccountsFixtures,
  # which does not exist in this tree, so the user is registered here instead.
  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "mapper#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, source} =
      Configuration.create_source(%{
        name: "Bikes",
        notes: "",
        type: :gbfs,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "gbfs", "url" => "https://e.test/gbfs.json", "lang" => "en"}
      })

    %{conn: log_in_user(conn, user), source: source}
  end

  defp add_from_map(conn, source, station_id) do
    {:ok, live, _html} = live(conn, Routes.source_show_path(conn, :show, source))

    render_hook(live, "add-query-from-map", %{
      "station_id" => station_id,
      "name" => "Dock",
      "type" => "station"
    })

    live
  end

  test "a station query that saves says so", %{conn: conn, source: source} do
    live = add_from_map(conn, source, "dock-1")

    assert has_element?(live, ".alert-info", "Query created successfully!")
    assert [%{name: "Dock - Station Query"}] = Configuration.get_queries(:source, source.id)
  end

  test "one that fails validation is not reported as created", %{conn: conn, source: source} do
    # No station id: the GBFS query changeset requires one.
    live = add_from_map(conn, source, "")

    assert has_element?(live, ".alert-error", "Could not create a query")
    refute has_element?(live, ".alert-info", "Query created successfully!")
    assert Configuration.get_queries(:source, source.id) == []
  end
end
