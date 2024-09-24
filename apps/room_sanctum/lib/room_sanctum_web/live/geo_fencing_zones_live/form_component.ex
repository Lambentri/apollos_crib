defmodule RoomSanctumWeb.GeoFencingZonesLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage geo_fencing_zones records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="geo_fencing_zones-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:place]} type="text" label="Place" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Geo fencing zones</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{geo_fencing_zones: geo_fencing_zones} = assigns, socket) do
    changeset = Storage.change_geo_fencing_zones(geo_fencing_zones)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"geo_fencing_zones" => geo_fencing_zones_params}, socket) do
    changeset =
      socket.assigns.geo_fencing_zones
      |> Storage.change_geo_fencing_zones(geo_fencing_zones_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"geo_fencing_zones" => geo_fencing_zones_params}, socket) do
    save_geo_fencing_zones(socket, socket.assigns.action, geo_fencing_zones_params)
  end

  defp save_geo_fencing_zones(socket, :edit, geo_fencing_zones_params) do
    case Storage.update_geo_fencing_zones(socket.assigns.geo_fencing_zones, geo_fencing_zones_params) do
      {:ok, geo_fencing_zones} ->
        notify_parent({:saved, geo_fencing_zones})

        {:noreply,
         socket
         |> put_flash(:info, "Geo fencing zones updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_geo_fencing_zones(socket, :new, geo_fencing_zones_params) do
    case Storage.create_geo_fencing_zones(geo_fencing_zones_params) do
      {:ok, geo_fencing_zones} ->
        notify_parent({:saved, geo_fencing_zones})

        {:noreply,
         socket
         |> put_flash(:info, "Geo fencing zones created successfully")
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
