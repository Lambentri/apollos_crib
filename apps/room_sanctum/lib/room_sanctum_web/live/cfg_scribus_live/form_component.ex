defmodule RoomSanctumWeb.ScribusLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage scribus records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="scribus-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:resolution]} type="select" label="Resolution" options={["850x480"]} />
        <.input
          field={@form[:configuration]}
          type="select"
          multiple
          label="Configuration"
          options={[]}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Scribus</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{scribus: scribus} = assigns, socket) do
    changeset = Configuration.change_scribus(scribus)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"scribus" => scribus_params}, socket) do
    changeset =
      socket.assigns.scribus
      |> Configuration.change_scribus(scribus_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"scribus" => scribus_params}, socket) do
    save_scribus(socket, socket.assigns.action, scribus_params)
  end

  defp save_scribus(socket, :edit, scribus_params) do
    case Configuration.update_scribus(socket.assigns.scribus, scribus_params) do
      {:ok, scribus} ->
        notify_parent({:saved, scribus})

        {:noreply,
         socket
         |> put_flash(:info, "Scribus updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_scribus(socket, :new, scribus_params) do
    case Configuration.create_scribus(scribus_params) do
      {:ok, scribus} ->
        notify_parent({:saved, scribus})

        {:noreply,
         socket
         |> put_flash(:info, "Scribus created successfully")
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
