defmodule RoomSanctumWeb.StopLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{stop: stop} = assigns, socket) do
    changeset = Storage.change_stop(stop)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"stop" => stop_params}, socket) do
    changeset =
      socket.assigns.stop
      |> Storage.change_stop(stop_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"stop" => stop_params}, socket) do
    save_stop(socket, socket.assigns.action, stop_params)
  end

  defp save_stop(socket, :edit, stop_params) do
    case Storage.update_stop(socket.assigns.stop, stop_params) do
      {:ok, _stop} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stop updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_stop(socket, :new, stop_params) do
    case Storage.create_stop(stop_params) do
      {:ok, _stop} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stop created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
