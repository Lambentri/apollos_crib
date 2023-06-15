defmodule RoomSanctumWeb.HourlyObsDataLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage.AirNow

  @impl true
  def update(%{hourly_obs_data: hourly_obs_data} = assigns, socket) do
    changeset = AirNow.change_hourly_obs_data(hourly_obs_data)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"hourly_obs_data" => hourly_obs_data_params}, socket) do
    changeset =
      socket.assigns.hourly_obs_data
      |> AirNow.change_hourly_obs_data(hourly_obs_data_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"hourly_obs_data" => hourly_obs_data_params}, socket) do
    save_hourly_obs_data(socket, socket.assigns.action, hourly_obs_data_params)
  end

  defp save_hourly_obs_data(socket, :edit, hourly_obs_data_params) do
    case AirNow.update_hourly_obs_data(socket.assigns.hourly_obs_data, hourly_obs_data_params) do
      {:ok, hourly_obs_data} ->
        notify_parent({:saved, hourly_obs_data})
        {:noreply,
         socket
         |> put_flash(:info, "Hourly obs data updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_hourly_obs_data(socket, :new, hourly_obs_data_params) do
    case AirNow.create_hourly_obs_data(hourly_obs_data_params) do
      {:ok, hourly_obs_data} ->
        notify_parent({:saved, hourly_obs_data})
        {:noreply,
         socket
         |> put_flash(:info, "Hourly obs data created successfully")
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
