defmodule RoomSanctumWeb.FociLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  defp normalize_ll(val) do
    cond do
      val < -180 -> val+360
      true -> val
    end
  end

  @impl true
  def update(%{foci: foci} = assigns, socket) do
    changeset = Configuration.change_foci(foci)

    {
      :ok,
      socket
      |> assign(assigns)
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
    lat_lng_pt = %Geo.Point{coordinates: {latlng["lat"] |> normalize_ll, latlng["lng"] |> normalize_ll}, srid: 4326}
    cs = socket.assigns.foci |> Ecto.Changeset.change(place: lat_lng_pt)
    #         |> Map.put(:action, :validate)
    # cs = socket.assigns.foci |> Configuration.change_foci(%{place: lat_lng_pt}) |> Map.put(:action, :validate)
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
