defmodule RoomSanctumWeb.SourceLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  defp inj_uid(params, socket) do
    params = params |> Map.put("user_id", socket.assigns.current_user.id)

    params =
      case Map.has_key?(params, "config") do
        true -> params
        false -> params |> Map.put("config", %{})
      end
  end

  @impl true
  def update(%{source: source} = assigns, socket) do
    changeset = Configuration.change_source(source)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tint_opts, ["amber", "violet", "emerald", "sky", "rose", "stone"])
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"source" => source_params}, socket) do
    source_params = inj_uid(source_params, socket)
    IO.inspect({"params", source_params})

    changeset =
      socket.assigns.source
      |> Configuration.change_source(source_params)
      |> Map.put(:action, :validate)

    IO.inspect(changeset.data)
    IO.inspect(changeset)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"source" => source_params}, socket) do
    source_params = inj_uid(source_params, socket)
    save_source(socket, socket.assigns.action, source_params)
  end

  defp save_source(socket, :edit, source_params) do
    case Configuration.update_source(socket.assigns.source, source_params) do
      {:ok, source} ->
        notify_parent({:saved, source})

        {:noreply,
         socket
         |> put_flash(:info, "Source updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_source(socket, :new, source_params) do
    case Configuration.create_source(source_params) do
      {:ok, source} ->
        notify_parent({:saved, source})

        {:noreply,
         socket
         |> put_flash(:info, "Source created successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
