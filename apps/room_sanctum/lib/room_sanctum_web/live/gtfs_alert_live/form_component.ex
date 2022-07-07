defmodule RoomSanctumWeb.AlertLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{alert: alert} = assigns, socket) do
    changeset = Storage.change_alert(alert)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"alert" => alert_params}, socket) do
    changeset =
      socket.assigns.alert
      |> Storage.change_alert(alert_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"alert" => alert_params}, socket) do
    save_alert(socket, socket.assigns.action, alert_params)
  end

  defp save_alert(socket, :edit, alert_params) do
    case Storage.update_alert(socket.assigns.alert, alert_params) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_alert(socket, :new, alert_params) do
    case Storage.create_alert(alert_params) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
