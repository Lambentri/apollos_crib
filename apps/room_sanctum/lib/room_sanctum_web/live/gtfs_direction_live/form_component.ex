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
      {:ok, direction} ->
        notify_parent({:saved, direction})
        {:noreply,
         socket
         |> put_flash(:info, "Direction updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_direction(socket, :new, direction_params) do
    case Storage.create_direction(direction_params) do
      {:ok, direction} ->
        notify_parent({:saved, direction})
        {:noreply,
         socket
         |> put_flash(:info, "Direction created successfully")
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
