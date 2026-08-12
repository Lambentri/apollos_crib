defmodule RoomSanctumWeb.FociEditTest do
  @moduledoc """
  Editing a foci, from both places that offer it.

  Two faults met on the same keystroke: the show page mounts without a
  current_user, which the form component reads on every validate, and both
  form components overwrite `place` with an assign that is only set once the
  map (or the coordinate box) has been touched -- so a rename dropped the
  point the foci is for.
  """
  use RoomSanctumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RoomSanctum.{Accounts, Configuration}
  alias RoomSanctumWeb.FociLive.{FormComponent, FormComponentCoords}

  @sfo %Geo.Point{coordinates: {-122.3841977119446, 37.62257668960213}, srid: 4326}

  # The map hook pushes its events to #foci-form, which LiveViewTest cannot
  # drive (the form carries phx-target, not phx-hook), so the tests that need
  # a pin drop go at the component directly.
  defp socket_for(component, ctx) do
    {:ok, socket} =
      component.update(
        %{
          foci: ctx.foci,
          id: ctx.foci.id,
          title: "Modify Foci",
          action: :edit,
          patch: "/",
          current_user: ctx.user
        },
        %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}
      )

    socket
  end

  defp typed_name(socket), do: Ecto.Changeset.get_field(socket.assigns.form.source, :name)

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        email: "foci#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    {:ok, foci} = Configuration.create_foci(%{name: "SFO", user_id: user.id, place: @sfo})

    %{conn: log_in_user(conn, user), user: user, foci: foci}
  end

  describe "from the foci's own page" do
    test "typing in a field does not take the page down", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :edit, ctx.foci))

      # the component reads socket.assigns.current_user, which this page
      # never assigned -- a KeyError on the first keystroke
      html =
        live
        |> form("#foci-form", foci: %{name: "SFO2"})
        |> render_change()

      assert html =~ "SFO2"
    end

    test "renaming keeps the place it is a foci for", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :edit, ctx.foci))

      live |> form("#foci-form", foci: %{name: "SFO2"}) |> render_submit()

      reloaded = Configuration.get_foci!(ctx.foci.id)
      assert reloaded.name == "SFO2"
      assert reloaded.place == @sfo
    end

    test "the place survives a validate before the save", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :edit, ctx.foci))

      form = form(live, "#foci-form", foci: %{name: "SFO2"})
      render_change(form)
      render_submit(form)

      assert Configuration.get_foci!(ctx.foci.id).place == @sfo
    end
  end

  describe "from the foci list" do
    test "renaming keeps the place", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.foci_index_path(ctx.conn, :edit, ctx.foci))

      live |> form("#foci-form", foci: %{name: "SFO2"}) |> render_submit()

      reloaded = Configuration.get_foci!(ctx.foci.id)
      assert reloaded.name == "SFO2"
      assert reloaded.place == @sfo
    end

    test "the coordinate editor keeps the place too", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.foci_index_path(ctx.conn, :edit_coords, ctx.foci))

      live |> form("#foci-form", foci: %{name: "SFO2"}) |> render_submit()

      reloaded = Configuration.get_foci!(ctx.foci.id)
      assert reloaded.name == "SFO2"
      assert reloaded.place == @sfo
    end

    test "a new foci still needs a place picked", ctx do
      {:ok, live, _html} = live(ctx.conn, Routes.foci_index_path(ctx.conn, :new))

      html = live |> form("#foci-form", foci: %{name: "Nowhere"}) |> render_submit()

      # place has no input, so the error had nowhere to render and the save
      # looked like a no-op
      assert html =~ "Pick a place on the map"
      assert Configuration.list_focis({:user, ctx.user.id}) |> length() == 1
    end
  end

  describe "picking a new place" do
    # The fallback is assign_new: a place clicked on the map must survive the
    # next update/2.
    test "the stored place is what the form falls back to", ctx do
      assert socket_for(FormComponent, ctx).assigns.place == @sfo
    end

    test "a place clicked on the map is not reset by the next re-render", ctx do
      {:noreply, socket} =
        FormComponent.handle_event(
          "map-update",
          %{"latlng" => %{"lat" => 42.3601, "lng" => -71.0589}},
          socket_for(FormComponent, ctx)
        )

      assert socket.assigns.place.coordinates == {-71.0589, 42.3601}

      # the parent re-rendering the component must not undo the pick
      {:ok, socket} =
        FormComponent.update(%{foci: ctx.foci, id: ctx.foci.id}, socket)

      assert socket.assigns.place.coordinates == {-71.0589, 42.3601}
    end
  end

  describe "renaming and moving the pin together" do
    # Each of these rebuilt the changeset from the stored record, so whatever
    # had been typed but not yet saved was thrown away.
    test "dragging the map keeps the name you typed", ctx do
      socket = socket_for(FormComponent, ctx)

      {:noreply, socket} =
        FormComponent.handle_event("validate", %{"foci" => %{"name" => "SFO2"}}, socket)

      assert typed_name(socket) == "SFO2"

      {:noreply, socket} =
        FormComponent.handle_event(
          "map-update",
          %{"latlng" => %{"lat" => 42.3601, "lng" => -71.0589}},
          socket
        )

      assert typed_name(socket) == "SFO2"
      assert socket.assigns.place.coordinates == {-71.0589, 42.3601}
    end

    test "the coordinate box keeps the name you typed", ctx do
      socket = socket_for(FormComponentCoords, ctx)

      {:noreply, socket} =
        FormComponentCoords.handle_event("validate", %{"foci" => %{"name" => "SFO2"}}, socket)

      {:noreply, socket} =
        FormComponentCoords.handle_event("coord-update", %{"coords" => "42.3601, -71.0589"}, socket)

      assert typed_name(socket) == "SFO2"
      assert socket.assigns.place.coordinates == {-71.0589, 42.3601}
    end

    test "nudging a single coordinate keeps the name you typed", ctx do
      socket = socket_for(FormComponentCoords, ctx)

      {:noreply, socket} =
        FormComponentCoords.handle_event("validate", %{"foci" => %{"name" => "SFO2"}}, socket)

      {:noreply, socket} =
        FormComponentCoords.handle_event("latitude-update", %{"value" => "42.3601"}, socket)

      assert typed_name(socket) == "SFO2"
      assert {_lon, 42.3601} = socket.assigns.place.coordinates
    end

    test "saving after both stores both", ctx do
      socket = socket_for(FormComponent, ctx)

      {:noreply, socket} =
        FormComponent.handle_event("validate", %{"foci" => %{"name" => "SFO2"}}, socket)

      {:noreply, socket} =
        FormComponent.handle_event(
          "map-update",
          %{"latlng" => %{"lat" => 42.3601, "lng" => -71.0589}},
          socket
        )

      {:noreply, _socket} =
        FormComponent.handle_event("save", %{"foci" => %{"name" => "SFO2"}}, socket)

      reloaded = Configuration.get_foci!(ctx.foci.id)
      assert reloaded.name == "SFO2"
      assert reloaded.place.coordinates == {-71.0589, 42.3601}
    end

    test "moving the pin twice still keeps the name", ctx do
      socket = socket_for(FormComponent, ctx)

      {:noreply, socket} =
        FormComponent.handle_event("validate", %{"foci" => %{"name" => "SFO2"}}, socket)

      socket =
        Enum.reduce([{42.36, -71.05}, {40.71, -74.0}], socket, fn {lat, lng}, acc ->
          {:noreply, acc} =
            FormComponent.handle_event(
              "map-update",
              %{"latlng" => %{"lat" => lat, "lng" => lng}},
              acc
            )

          acc
        end)

      assert typed_name(socket) == "SFO2"
      assert socket.assigns.place.coordinates == {-74.0, 40.71}
    end
  end

  describe "the edit page itself" do
    test "renders with the foci's name in the form", ctx do
      {:ok, _live, html} = live(ctx.conn, Routes.foci_show_path(ctx.conn, :edit, ctx.foci))

      assert html =~ ~s(value="SFO")
    end
  end
end
