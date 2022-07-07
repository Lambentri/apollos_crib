defmodule RoomSanctumWeb.DirectionLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{direction: direction} = assigns, socket) do
    changeset = Storage.change_direction(direction)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"direction" => direction_params}, socket) do
    changeset =
      socket.assigns.direction
      |> Storage.change_direction(direction_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"direction" => direction_params}, socket) do
    save_direction(socket, socket.assigns.action, direction_params)
  end

  defp save_direction(socket, :edit, direction_params) do
    case Storage.update_direction(socket.assigns.direction, direction_params) do
      {:ok, _direction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Direction updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_direction(socket, :new, direction_params) do
    case Storage.create_direction(direction_params) do
      {:ok, _direction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Direction created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
