defmodule RoomSanctumWeb.HourlyDataLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{hourly_data: hourly_data} = assigns, socket) do
    changeset = Storage.change_hourly_data(hourly_data)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"hourly_data" => hourly_data_params}, socket) do
    changeset =
      socket.assigns.hourly_data
      |> Storage.change_hourly_data(hourly_data_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"hourly_data" => hourly_data_params}, socket) do
    save_hourly_data(socket, socket.assigns.action, hourly_data_params)
  end

  defp save_hourly_data(socket, :edit, hourly_data_params) do
    case Storage.update_hourly_data(socket.assigns.hourly_data, hourly_data_params) do
      {:ok, hourly_data} ->
        notify_parent({:saved, hourly_data})

        {:noreply,
         socket
         |> put_flash(:info, "Hourly data updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_hourly_data(socket, :new, hourly_data_params) do
    case Storage.create_hourly_data(hourly_data_params) do
      {:ok, hourly_data} ->
        notify_parent({:saved, hourly_data})

        {:noreply,
         socket
         |> put_flash(:info, "Hourly data created successfully")
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
