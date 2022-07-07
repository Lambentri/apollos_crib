defmodule RoomSanctumWeb.MonitoringSiteLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{monitoring_site: monitoring_site} = assigns, socket) do
    changeset = Storage.change_monitoring_site(monitoring_site)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"monitoring_site" => monitoring_site_params}, socket) do
    changeset =
      socket.assigns.monitoring_site
      |> Storage.change_monitoring_site(monitoring_site_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"monitoring_site" => monitoring_site_params}, socket) do
    save_monitoring_site(socket, socket.assigns.action, monitoring_site_params)
  end

  defp save_monitoring_site(socket, :edit, monitoring_site_params) do
    case Storage.update_monitoring_site(socket.assigns.monitoring_site, monitoring_site_params) do
      {:ok, _monitoring_site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Monitoring site updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_monitoring_site(socket, :new, monitoring_site_params) do
    case Storage.create_monitoring_site(monitoring_site_params) do
      {:ok, _monitoring_site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Monitoring site created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
