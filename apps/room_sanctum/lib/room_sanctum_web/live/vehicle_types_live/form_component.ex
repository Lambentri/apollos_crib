defmodule RoomSanctumWeb.VehicleTypesLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage vehicle_types records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="vehicle_types-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:vehicle_type_id]} type="text" label="Vehicle type" />
        <.input field={@form[:form_factor]} type="text" label="Form factor" />
        <.input field={@form[:propulsion_type]} type="text" label="Propulsion type" />
        <.input field={@form[:max_range_meters]} type="number" label="Max range meters" step="any" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Vehicle types</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{vehicle_types: vehicle_types} = assigns, socket) do
    changeset = Storage.change_vehicle_types(vehicle_types)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"vehicle_types" => vehicle_types_params}, socket) do
    changeset =
      socket.assigns.vehicle_types
      |> Storage.change_vehicle_types(vehicle_types_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"vehicle_types" => vehicle_types_params}, socket) do
    save_vehicle_types(socket, socket.assigns.action, vehicle_types_params)
  end

  defp save_vehicle_types(socket, :edit, vehicle_types_params) do
    case Storage.update_vehicle_types(socket.assigns.vehicle_types, vehicle_types_params) do
      {:ok, vehicle_types} ->
        notify_parent({:saved, vehicle_types})

        {:noreply,
         socket
         |> put_flash(:info, "Vehicle types updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_vehicle_types(socket, :new, vehicle_types_params) do
    case Storage.create_vehicle_types(vehicle_types_params) do
      {:ok, vehicle_types} ->
        notify_parent({:saved, vehicle_types})

        {:noreply,
         socket
         |> put_flash(:info, "Vehicle types created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
