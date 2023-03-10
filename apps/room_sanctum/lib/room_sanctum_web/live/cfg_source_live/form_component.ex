defmodule RoomSanctumWeb.SourceLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  defp inj_uid(params, socket) do
    params |> Map.put("user_id", socket.assigns.current_user.id)
  end

  @impl true
  def update(%{source: source} = assigns, socket) do
    changeset = Configuration.change_source(source)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"source" => source_params}, socket) do
    source_params = inj_uid(source_params, socket)

    changeset =
      socket.assigns.source
      |> Configuration.change_source(source_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"source" => source_params}, socket) do
    source_params = inj_uid(source_params, socket)
    save_source(socket, socket.assigns.action, source_params) |> IO.inspect
  end

  defp save_source(socket, :edit, source_params) do
    case Configuration.update_source(socket.assigns.source, source_params) do
      {:ok, _source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_source(socket, :new, source_params) do
    case Configuration.create_source(source_params) do
      {:ok, _source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
