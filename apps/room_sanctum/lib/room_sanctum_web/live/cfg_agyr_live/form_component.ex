defmodule RoomSanctumWeb.AgyrLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage agyr records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="agyr-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:designator]} type="text" label="Designator" />
        <.input field={@form[:path]} type="text" label="Path" />
        <.input field={@form[:user]} type="text" label="User" />
        <.input field={@form[:token]} type="text" label="Token" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Agyr</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{agyr: agyr} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Configuration.change_agyr(agyr))
     end)}
  end

  @impl true
  def handle_event("validate", %{"agyr" => agyr_params}, socket) do
    changeset = Configuration.change_agyr(socket.assigns.agyr, agyr_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"agyr" => agyr_params}, socket) do
    save_agyr(socket, socket.assigns.action, agyr_params)
  end

  defp save_agyr(socket, :edit, agyr_params) do
    case Configuration.update_agyr(socket.assigns.agyr, agyr_params) do
      {:ok, agyr} ->
        notify_parent({:saved, agyr})

        {:noreply,
         socket
         |> put_flash(:info, "Agyr updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_agyr(socket, :new, agyr_params) do
    case Configuration.create_agyr(agyr_params) do
      {:ok, agyr} ->
        notify_parent({:saved, agyr})

        {:noreply,
         socket
         |> put_flash(:info, "Agyr created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
