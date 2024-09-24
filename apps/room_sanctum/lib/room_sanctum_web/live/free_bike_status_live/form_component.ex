defmodule RoomSanctumWeb.FreeBikeStatusLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage.GBFS.V1

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage free_bike_status records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="free_bike_status-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:bike_id]} type="text" label="Bike" />
        <.input field={@form[:lat]} type="text" label="Lat" />
        <.input field={@form[:lon]} type="text" label="Lon" />
        <.input field={@form[:point]} type="text" label="Point" />
        <.input field={@form[:is_disabled]} type="checkbox" label="Is disabled" />
        <.input field={@form[:is_reserved]} type="checkbox" label="Is reserved" />
        <.input field={@form[:vehicle_type_id]} type="text" label="Vehicle type" />
        <.input field={@form[:last_reported]} type="datetime-local" label="Last reported" />
        <.input field={@form[:current_range_meters]} type="number" label="Current range meters" />
        <.input field={@form[:current_fuel_percent]} type="number" label="Current fuel percent" step="any" />
        <.input field={@form[:pricing_plan_id]} type="text" label="Pricing plan" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Free bike status</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{free_bike_status: free_bike_status} = assigns, socket) do
    changeset = V1.change_free_bike_status(free_bike_status)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"free_bike_status" => free_bike_status_params}, socket) do
    changeset =
      socket.assigns.free_bike_status
      |> V1.change_free_bike_status(free_bike_status_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"free_bike_status" => free_bike_status_params}, socket) do
    save_free_bike_status(socket, socket.assigns.action, free_bike_status_params)
  end

  defp save_free_bike_status(socket, :edit, free_bike_status_params) do
    case V1.update_free_bike_status(socket.assigns.free_bike_status, free_bike_status_params) do
      {:ok, free_bike_status} ->
        notify_parent({:saved, free_bike_status})

        {:noreply,
         socket
         |> put_flash(:info, "Free bike status updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_free_bike_status(socket, :new, free_bike_status_params) do
    case V1.create_free_bike_status(free_bike_status_params) do
      {:ok, free_bike_status} ->
        notify_parent({:saved, free_bike_status})

        {:noreply,
         socket
         |> put_flash(:info, "Free bike status created successfully")
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
