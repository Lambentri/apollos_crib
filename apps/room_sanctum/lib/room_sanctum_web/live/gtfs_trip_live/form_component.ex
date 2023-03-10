defmodule RoomSanctumWeb.TripLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{trip: trip} = assigns, socket) do
    changeset = Storage.change_trip(trip)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"trip" => trip_params}, socket) do
    changeset =
      socket.assigns.trip
      |> Storage.change_trip(trip_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"trip" => trip_params}, socket) do
    save_trip(socket, socket.assigns.action, trip_params)
  end

  defp save_trip(socket, :edit, trip_params) do
    case Storage.update_trip(socket.assigns.trip, trip_params) do
      {:ok, _trip} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trip updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_trip(socket, :new, trip_params) do
    case Storage.create_trip(trip_params) do
      {:ok, _trip} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trip created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
