defmodule RoomSanctumWeb.SystemPricingPlansLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage system_pricing_plans records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="system_pricing_plans-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:plan_id]} type="text" label="Plan" />
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:currency]} type="text" label="Currency" />
        <.input field={@form[:price]} type="number" label="Price" step="any" />
        <.input field={@form[:is_taxable]} type="checkbox" label="Is taxable" />
        <.input field={@form[:description]} type="text" label="Description" />
        <:actions>
          <.button phx-disable-with="Saving...">Save System pricing plans</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{system_pricing_plans: system_pricing_plans} = assigns, socket) do
    changeset = Storage.change_system_pricing_plans(system_pricing_plans)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"system_pricing_plans" => system_pricing_plans_params}, socket) do
    changeset =
      socket.assigns.system_pricing_plans
      |> Storage.change_system_pricing_plans(system_pricing_plans_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"system_pricing_plans" => system_pricing_plans_params}, socket) do
    save_system_pricing_plans(socket, socket.assigns.action, system_pricing_plans_params)
  end

  defp save_system_pricing_plans(socket, :edit, system_pricing_plans_params) do
    case Storage.update_system_pricing_plans(socket.assigns.system_pricing_plans, system_pricing_plans_params) do
      {:ok, system_pricing_plans} ->
        notify_parent({:saved, system_pricing_plans})

        {:noreply,
         socket
         |> put_flash(:info, "System pricing plans updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_system_pricing_plans(socket, :new, system_pricing_plans_params) do
    case Storage.create_system_pricing_plans(system_pricing_plans_params) do
      {:ok, system_pricing_plans} ->
        notify_parent({:saved, system_pricing_plans})

        {:noreply,
         socket
         |> put_flash(:info, "System pricing plans created successfully")
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
