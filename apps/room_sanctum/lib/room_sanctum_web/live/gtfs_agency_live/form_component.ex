defmodule RoomSanctumWeb.AgencyLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{agency: agency} = assigns, socket) do
    changeset = Storage.change_agency(agency)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"agency" => agency_params}, socket) do
    changeset =
      socket.assigns.agency
      |> Storage.change_agency(agency_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"agency" => agency_params}, socket) do
    save_agency(socket, socket.assigns.action, agency_params)
  end

  defp save_agency(socket, :edit, agency_params) do
    case Storage.update_agency(socket.assigns.agency, agency_params) do
      {:ok, _agency} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agency updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_agency(socket, :new, agency_params) do
    case Storage.create_agency(agency_params) do
      {:ok, _agency} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agency created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
