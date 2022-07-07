defmodule RoomSanctumWeb.SysInfoLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{sys_info: sys_info} = assigns, socket) do
    changeset = Storage.change_sys_info(sys_info)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"sys_info" => sys_info_params}, socket) do
    changeset =
      socket.assigns.sys_info
      |> Storage.change_sys_info(sys_info_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"sys_info" => sys_info_params}, socket) do
    save_sys_info(socket, socket.assigns.action, sys_info_params)
  end

  defp save_sys_info(socket, :edit, sys_info_params) do
    case Storage.update_sys_info(socket.assigns.sys_info, sys_info_params) do
      {:ok, _sys_info} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sys info updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_sys_info(socket, :new, sys_info_params) do
    case Storage.create_sys_info(sys_info_params) do
      {:ok, _sys_info} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sys info created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
