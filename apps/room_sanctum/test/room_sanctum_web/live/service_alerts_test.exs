defmodule RoomSanctumWeb.ServiceAlertsTest do
  @moduledoc """
  The service alerts pane on an offering.

  The alerts themselves come from the GTFS-RT worker, which lives in another
  app and cannot be loaded here, so these cover what this app decides: when the
  pane appears at all, and how an alert is labelled.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}
  alias RoomSanctumWeb.SourceLive.Show

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "alert#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  defp source(user, config) do
    {:ok, source} =
      Configuration.create_source(%{
        name: "T", notes: "", type: :gtfs, enabled: true,
        user_id: user.id, config: config
      })

    source
  end

  describe "when the pane is shown" do
    test "not for a source with no alert feed configured", ctx do
      src = source(ctx.user, %{"__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC"})

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))
      send(live.pid, :update_sec)

      refute render(live) =~ "Service Alerts"
    end

    test "not for a source of a type that has no alerts", ctx do
      {:ok, src} =
        Configuration.create_source(%{
          name: "Markets", notes: "", type: :bourse, enabled: true,
          user_id: ctx.user.id, config: %{"__type__" => "bourse"}
        })

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))
      send(live.pid, :update_sec)

      refute render(live) =~ "Service Alerts"
    end

    test "an alert feed being configured does not by itself crash the page", ctx do
      # the worker is not running here, which is the same shape as a disabled
      # source or one that has not fetched yet
      src =
        source(ctx.user, %{
          "__type__" => "gtfs", "url" => "https://e.test/g.zip", "tz" => "UTC",
          "url_rt_sa" => "https://e.test/alerts.pb"
        })

      {:ok, live, _html} = live(ctx.conn, Routes.source_show_path(ctx.conn, :show, src))
      send(live.pid, :update_sec)

      assert Process.alive?(live.pid)
      # nothing to show, so no empty pane either
      refute render(live) =~ "Service Alerts"
    end
  end

  describe "labelling an alert" do
    test "reads as a sentence rather than a constant" do
      assert Show.alert_effect_label("STOP_MOVED") == "Stop moved"
      assert Show.alert_effect_label("ACCESSIBILITY_ISSUE") == "Accessibility issue"
      assert Show.alert_effect_label("NO_SERVICE") == "No service"
    end

    test "service disruptions stand out from notices" do
      assert Show.alert_effect_class("NO_SERVICE") == "badge-error"

      for effect <- ~w(REDUCED_SERVICE SIGNIFICANT_DELAYS DETOUR STOP_MOVED) do
        assert Show.alert_effect_class(effect) == "badge-warning", effect
      end

      # the two thirds of MBTA's feed that are notices should not shout
      for effect <- ~w(ACCESSIBILITY_ISSUE OTHER_EFFECT UNKNOWN_EFFECT) do
        assert Show.alert_effect_class(effect) == "badge-ghost", effect
      end
    end

    test "an effect nobody anticipated still renders" do
      assert Show.alert_effect_label("SOME_NEW_EFFECT") == "Some new effect"
      assert Show.alert_effect_class("SOME_NEW_EFFECT") == "badge-ghost"
    end
  end
end
