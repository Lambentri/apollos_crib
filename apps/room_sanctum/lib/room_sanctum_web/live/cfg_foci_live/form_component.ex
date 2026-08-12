defmodule RoomSanctumWeb.FociLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  defp normalize_ll(val) do
    cond do
      val < -180 -> val + 360
      true -> val
    end
  end

  # Moving the pin must not discard what has been typed but not yet saved, so
  # the changeset is rebuilt from the form's current params rather than from
  # the stored record. No :action is set, so a half-filled form does not start
  # showing errors just because the map was touched.
  defp with_place(socket, place) do
    params = socket |> current_params() |> Map.put("place", place)

    Configuration.change_foci(socket.assigns.foci, params)
  end

  defp current_params(%{assigns: %{form: %Phoenix.HTML.Form{source: %Ecto.Changeset{params: p}}}})
       when is_map(p),
       do: p

  defp current_params(_socket), do: %{}

  @impl true
  def update(%{foci: foci} = assigns, socket) do
    changeset = Configuration.change_foci(foci)

    {
      :ok,
      socket
      |> assign(assigns)
      # validate and save both write this over the params, so without it a
      # foci edited by any other field loses the point it is a foci for.
      # assign_new, so a place picked off the map is not reset by a re-render.
      |> assign_new(:place, fn -> foci.place end)
      |> assign_form(changeset)
    }
  end

  @impl true
  def handle_event("validate", %{"foci" => foci_params}, socket) do
    foci_params =
      inj_uid(foci_params, socket)
      |> Map.put(
        "place",
        socket.assigns
        |> Map.get(:place)
      )

    changeset =
      socket.assigns.foci
      |> Configuration.change_foci(foci_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"foci" => foci_params}, socket) do
    foci_params =
      inj_uid(foci_params, socket)
      |> Map.put(
        "place",
        socket.assigns
        |> Map.get(:place)
      )

    save_foci(socket, socket.assigns.action, foci_params)
  end

  def handle_event("map-update", %{"latlng" => latlng}, socket) do
    # {lon, lat}, as PostGIS and GeoJSON expect.
    lat_lng_pt = %Geo.Point{
      coordinates: {latlng["lng"] |> normalize_ll, latlng["lat"] |> normalize_ll},
      srid: 4326
    }

    cs = with_place(socket, lat_lng_pt)

    {
      :noreply,
      socket
      |> assign(:changeset, cs)
      |> assign_form(cs)
      |> assign(:place, lat_lng_pt)
    }
  end

  defp save_foci(socket, :edit, foci_params) do
    case Configuration.update_foci(socket.assigns.foci, foci_params) do
      {:ok, foci} ->
        notify_parent({:saved, foci})

        {
          :noreply,
          socket
          |> put_flash(:info, "Foci updated successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_foci(socket, :new, foci_params) do
    case Configuration.create_foci(foci_params) do
      {:ok, foci} ->
        notify_parent({:saved, foci})

        {
          :noreply,
          socket
          |> put_flash(:info, "Foci created successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp getlatlng(%{:place => nil}) do
    nil
  end

  defp getlatlng(%{:place => place}) do
    place |> Map.get(:coordinates, {}) |> Tuple.to_list() |> Poison.encode!()
  end
end
