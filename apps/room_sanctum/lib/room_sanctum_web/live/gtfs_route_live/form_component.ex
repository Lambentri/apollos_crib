defmodule RoomSanctumWeb.RouteLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{route: route} = assigns, socket) do
    changeset = Storage.change_route(route)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"route" => route_params}, socket) do
    changeset =
      socket.assigns.route
      |> Storage.change_route(route_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"route" => route_params}, socket) do
    save_route(socket, socket.assigns.action, route_params)
  end

  defp save_route(socket, :edit, route_params) do
    case Storage.update_route(socket.assigns.route, route_params) do
      {:ok, _route} ->
        {:noreply,
         socket
         |> put_flash(:info, "Route updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_route(socket, :new, route_params) do
    case Storage.create_route(route_params) do
      {:ok, _route} ->
        {:noreply,
         socket
         |> put_flash(:info, "Route created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
