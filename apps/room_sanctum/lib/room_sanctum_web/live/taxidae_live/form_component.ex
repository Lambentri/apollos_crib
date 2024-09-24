defmodule RoomSanctumWeb.TaxidaeLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage taxidae records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="taxidae-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:body]} type="text" label="Body" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Taxidae</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{taxidae: taxidae} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Storage.change_taxidae(taxidae))
     end)}
  end

  @impl true
  def handle_event("validate", %{"taxidae" => taxidae_params}, socket) do
    changeset = Storage.change_taxidae(socket.assigns.taxidae, taxidae_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"taxidae" => taxidae_params}, socket) do
    save_taxidae(socket, socket.assigns.action, taxidae_params)
  end

  defp save_taxidae(socket, :edit, taxidae_params) do
    case Storage.update_taxidae(socket.assigns.taxidae, taxidae_params) do
      {:ok, taxidae} ->
        notify_parent({:saved, taxidae})

        {:noreply,
         socket
         |> put_flash(:info, "Taxidae updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_taxidae(socket, :new, taxidae_params) do
    case Storage.create_taxidae(taxidae_params) do
      {:ok, taxidae} ->
        notify_parent({:saved, taxidae})

        {:noreply,
         socket
         |> put_flash(:info, "Taxidae created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
