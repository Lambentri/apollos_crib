defmodule RoomSanctumWeb.StationStatusLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{station_status: station_status} = assigns, socket) do
    changeset = Storage.change_station_status(station_status)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"station_status" => station_status_params}, socket) do
    changeset =
      socket.assigns.station_status
      |> Storage.change_station_status(station_status_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"station_status" => station_status_params}, socket) do
    save_station_status(socket, socket.assigns.action, station_status_params)
  end

  defp save_station_status(socket, :edit, station_status_params) do
    case Storage.update_station_status(socket.assigns.station_status, station_status_params) do
      {:ok, station_status} ->
        notify_parent({:saved, station_status})
        {:noreply,
         socket
         |> put_flash(:info, "Station status updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_station_status(socket, :new, station_status_params) do
    case Storage.create_station_status(station_status_params) do
      {:ok, station_status} ->
        notify_parent({:saved, station_status})
        {:noreply,
         socket
         |> put_flash(:info, "Station status created successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
