defmodule RoomSanctumWeb.StationInfoLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{station_info: station_info} = assigns, socket) do
    changeset = Storage.change_station_info(station_info)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"station_info" => station_info_params}, socket) do
    changeset =
      socket.assigns.station_info
      |> Storage.change_station_info(station_info_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"station_info" => station_info_params}, socket) do
    save_station_info(socket, socket.assigns.action, station_info_params)
  end

  defp save_station_info(socket, :edit, station_info_params) do
    case Storage.update_station_info(socket.assigns.station_info, station_info_params) do
      {:ok, station_info} ->
        notify_parent({:saved, station_info})

        {:noreply,
         socket
         |> put_flash(:info, "Station info updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_station_info(socket, :new, station_info_params) do
    case Storage.create_station_info(station_info_params) do
      {:ok, station_info} ->
        notify_parent({:saved, station_info})

        {:noreply,
         socket
         |> put_flash(:info, "Station info created successfully")
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
