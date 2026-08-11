defmodule RoomSanctumWeb.VisionTintTest do
  @moduledoc """
  A vision can carry a tint, the same way a source or a query does.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "tint#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  defp vision(user, attrs \\ %{}) do
    {:ok, vision} =
      Configuration.create_vision(Map.merge(%{name: "Dash", user_id: user.id}, attrs))

    vision
  end

  describe "storing a tint" do
    test "a vision keeps the colour it was given", ctx do
      v = vision(ctx.user, %{meta: %{tint: "teal"}})

      assert Configuration.get_vision!(v.id).meta.tint == "teal"
    end

    test "a vision without one is fine", ctx do
      v = vision(ctx.user)

      assert v.meta == nil or v.meta.tint == nil
    end

    test "the tint can be changed and cleared", ctx do
      v = vision(ctx.user, %{meta: %{tint: "teal"}})

      {:ok, v} = Configuration.update_vision(v, %{meta: %{tint: "rose"}})
      assert v.meta.tint == "rose"

      {:ok, v} = Configuration.update_vision(v, %{meta: %{tint: ""}})
      assert v.meta.tint == nil
    end

    test "a colour with no stylesheet behind it is refused", ctx do
      assert {:error, changeset} =
               Configuration.create_vision(%{
                 name: "Bad", user_id: ctx.user.id, meta: %{tint: "chartreuse"}
               })

      assert %{tint: ["unknown colour"]} =
               changeset
               |> Ecto.Changeset.get_change(:meta)
               |> Map.fetch!(:errors)
               |> Enum.into(%{}, fn {field, {msg, _opts}} -> {field, [msg]} end)
    end

    test "daisyui's neutral is refused, since it has no numbered scale", ctx do
      assert {:error, _} =
               Configuration.create_vision(%{
                 name: "Bad", user_id: ctx.user.id, meta: %{tint: "neutral"}
               })
    end

    test "every colour the picker offers is accepted", ctx do
      for tint <- RoomSanctum.Tints.all() do
        assert {:ok, v} =
                 Configuration.create_vision(%{
                   name: "V #{tint}", user_id: ctx.user.id, meta: %{tint: tint}
                 })

        assert v.meta.tint == tint
      end
    end
  end

  describe "the editor" do
    # The picker first went into cfg_vision_live/form_component.html.heex,
    # which nothing renders: the component defines render/1 inline, and that
    # wins. Storage and display tests both passed while the picker was
    # invisible, so these drive the editor itself.
    test "offers the palette when editing an untinted vision", ctx do
      v = vision(ctx.user)

      {:ok, _live, html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :edit, v))

      assert html =~ ">Tint<"

      assert length(Regex.scan(~r/vision\[meta\]\[tint\]/, html)) ==
               length(RoomSanctum.Tints.all()) + 1
    end

    test "offers the palette for a brand new vision", ctx do
      {:ok, _live, html} = live(ctx.conn, Routes.vision_index_path(ctx.conn, :new))

      assert length(Regex.scan(~r/vision\[meta\]\[tint\]/, html)) ==
               length(RoomSanctum.Tints.all()) + 1
    end

    test "pre-selects the tint the vision already has", ctx do
      v = vision(ctx.user, %{meta: %{tint: "teal"}})

      {:ok, _live, html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :edit, v))

      assert html =~ ~s(value="teal" class="sr-only" checked)
      refute html =~ ~s(value="rose" class="sr-only" checked)
    end

    test "saving from the form keeps the tint", ctx do
      v = vision(ctx.user)

      {:ok, live, _html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :edit, v))

      live
      |> form("#vision-form", vision: %{name: "Dash", meta: %{tint: "orange"}})
      |> render_submit()

      assert Configuration.get_vision!(v.id).meta.tint == "orange"
    end
  end

  describe "showing it" do
    test "the vision list marks a tinted vision", ctx do
      vision(ctx.user, %{meta: %{tint: "teal"}})

      {:ok, _live, html} = live(ctx.conn, Routes.vision_index_path(ctx.conn, :index))

      assert html =~ "text-teal-500"
    end

    test "the vision's own page shows it beside the name", ctx do
      v = vision(ctx.user, %{meta: %{tint: "teal"}})

      {:ok, _live, html} = live(ctx.conn, Routes.vision_show_path(ctx.conn, :show, v))

      assert html =~ "text-teal-500"
      # beside the name, not somewhere else on the page
      assert html =~ ~r/text-teal-500.{0,120}Dash/s
    end

    # The pythiae page cannot be rendered from this app's tests: it reads
    # users_rabbit, which belongs to room_hermes and is not migrated into
    # room_sanctum's test database. Its dot comes from the same tint_dot
    # component covered below.

    test "an untinted vision gets no dot", ctx do
      vision(ctx.user)

      {:ok, _live, html} = live(ctx.conn, Routes.vision_index_path(ctx.conn, :index))

      refute html =~ "fa-circle mr-2 text-"
    end

    test "a query's page shows the tint of the visions it belongs to", ctx do
      {:ok, source} =
        Configuration.create_source(%{
          name: "Markets", notes: "", type: :bourse, enabled: true,
          user_id: ctx.user.id, config: %{"__type__" => "bourse"}
        })

      {:ok, query} =
        Configuration.create_query(%{
          name: "AAPL", notes: "", source_id: source.id, user_id: ctx.user.id,
          query: %{"__type__" => "bourse", "symbol" => "AAPL"}
        })

      v = vision(ctx.user, %{meta: %{tint: "fuchsia"}})

      {:ok, live, _html} = live(ctx.conn, Routes.query_show_path(ctx.conn, :show, query))
      send(live.pid, :update_sec)
      _ = render(live)
      render_click(live, "add-to", %{"vision" => to_string(v.id)})
      Process.sleep(50)
      send(live.pid, :update_sec)

      assert render(live) =~ "text-fuchsia-500"
    end
  end
end
