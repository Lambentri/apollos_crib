defmodule RoomSanctumWeb.ReportingAreaLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{reporting_area: reporting_area} = assigns, socket) do
    changeset = Storage.change_reporting_area(reporting_area)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"reporting_area" => reporting_area_params}, socket) do
    changeset =
      socket.assigns.reporting_area
      |> Storage.change_reporting_area(reporting_area_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"reporting_area" => reporting_area_params}, socket) do
    save_reporting_area(socket, socket.assigns.action, reporting_area_params)
  end

  defp save_reporting_area(socket, :edit, reporting_area_params) do
    case Storage.update_reporting_area(socket.assigns.reporting_area, reporting_area_params) do
      {:ok, _reporting_area} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reporting area updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_reporting_area(socket, :new, reporting_area_params) do
    case Storage.create_reporting_area(reporting_area_params) do
      {:ok, _reporting_area} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reporting area created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
