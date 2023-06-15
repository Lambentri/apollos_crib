defmodule RoomSanctumWeb.AlertLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{alert: alert} = assigns, socket) do
    changeset = Storage.change_gbfs_alert(alert)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"alert" => alert_params}, socket) do
    changeset =
      socket.assigns.alert
      |> Storage.change_gbfs_alert(alert_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"alert" => alert_params}, socket) do
    save_alert(socket, socket.assigns.action, alert_params)
  end

  defp save_alert(socket, :edit, alert_params) do
    case Storage.update_gbfs_alert(socket.assigns.alert, alert_params) do
      {:ok, alert} ->
        notify_parent({:saved, alert})
        {:noreply,
         socket
         |> put_flash(:info, "Alert updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_alert(socket, :new, alert_params) do
    case Storage.create_gbfs_alert(alert_params) do
      {:ok, alert} ->
        notify_parent({:saved, alert})
        {:noreply,
         socket
         |> put_flash(:info, "Alert created successfully")
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
