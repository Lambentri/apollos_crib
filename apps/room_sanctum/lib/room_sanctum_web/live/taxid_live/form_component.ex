defmodule RoomSanctumWeb.TaxidLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage taxid records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="taxid-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:designator]} type="text" label="Designator" />
        <.input field={@form[:user]} type="text" label="User" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Taxid</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{taxid: taxid} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Configuration.change_taxid(taxid))
     end)}
  end

  @impl true
  def handle_event("validate", %{"taxid" => taxid_params}, socket) do
    changeset = Configuration.change_taxid(socket.assigns.taxid, taxid_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"taxid" => taxid_params}, socket) do
    save_taxid(socket, socket.assigns.action, taxid_params)
  end

  defp save_taxid(socket, :edit, taxid_params) do
    case Configuration.update_taxid(socket.assigns.taxid, taxid_params) do
      {:ok, taxid} ->
        notify_parent({:saved, taxid})

        {:noreply,
         socket
         |> put_flash(:info, "Taxid updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_taxid(socket, :new, taxid_params) do
    case Configuration.create_taxid(taxid_params) do
      {:ok, taxid} ->
        notify_parent({:saved, taxid})

        {:noreply,
         socket
         |> put_flash(:info, "Taxid created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
