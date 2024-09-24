defmodule RoomSanctumWeb.EbikesAtStationsLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage ebikes_at_stations records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="ebikes_at_stations-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:station_id]} type="text" label="Station" />
        <.input
          field={@form[:ebikes]}
          type="select"
          multiple
          label="Ebikes"
          options={[]}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Ebikes at stations</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{ebikes_at_stations: ebikes_at_stations} = assigns, socket) do
    changeset = Storage.change_ebikes_at_stations(ebikes_at_stations)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"ebikes_at_stations" => ebikes_at_stations_params}, socket) do
    changeset =
      socket.assigns.ebikes_at_stations
      |> Storage.change_ebikes_at_stations(ebikes_at_stations_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"ebikes_at_stations" => ebikes_at_stations_params}, socket) do
    save_ebikes_at_stations(socket, socket.assigns.action, ebikes_at_stations_params)
  end

  defp save_ebikes_at_stations(socket, :edit, ebikes_at_stations_params) do
    case Storage.update_ebikes_at_stations(socket.assigns.ebikes_at_stations, ebikes_at_stations_params) do
      {:ok, ebikes_at_stations} ->
        notify_parent({:saved, ebikes_at_stations})

        {:noreply,
         socket
         |> put_flash(:info, "Ebikes at stations updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_ebikes_at_stations(socket, :new, ebikes_at_stations_params) do
    case Storage.create_ebikes_at_stations(ebikes_at_stations_params) do
      {:ok, ebikes_at_stations} ->
        notify_parent({:saved, ebikes_at_stations})

        {:noreply,
         socket
         |> put_flash(:info, "Ebikes at stations created successfully")
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
