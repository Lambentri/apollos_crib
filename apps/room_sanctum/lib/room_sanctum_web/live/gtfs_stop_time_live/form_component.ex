defmodule RoomSanctumWeb.StopTimeLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{stop_time: stop_time} = assigns, socket) do
    changeset = Storage.change_stop_time(stop_time)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"stop_time" => stop_time_params}, socket) do
    changeset =
      socket.assigns.stop_time
      |> Storage.change_stop_time(stop_time_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"stop_time" => stop_time_params}, socket) do
    save_stop_time(socket, socket.assigns.action, stop_time_params)
  end

  defp save_stop_time(socket, :edit, stop_time_params) do
    case Storage.update_stop_time(socket.assigns.stop_time, stop_time_params) do
      {:ok, stop_time} ->
        notify_parent({:saved, stop_time})
        {:noreply,
         socket
         |> put_flash(:info, "Stop time updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_stop_time(socket, :new, stop_time_params) do
    case Storage.create_stop_time(stop_time_params) do
      {:ok, stop_time} ->
        notify_parent({:saved, stop_time})
        {:noreply,
         socket
         |> put_flash(:info, "Stop time created successfully")
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
