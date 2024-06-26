defmodule RoomSanctumWeb.CalendarLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Storage

  @impl true
  def update(%{calendar: calendar} = assigns, socket) do
    changeset = Storage.change_calendar(calendar)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"calendar" => calendar_params}, socket) do
    changeset =
      socket.assigns.calendar
      |> Storage.change_calendar(calendar_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"calendar" => calendar_params}, socket) do
    save_calendar(socket, socket.assigns.action, calendar_params)
  end

  defp save_calendar(socket, :edit, calendar_params) do
    case Storage.update_calendar(socket.assigns.calendar, calendar_params) do
      {:ok, calendar} ->
        notify_parent({:saved, calendar})

        {:noreply,
         socket
         |> put_flash(:info, "Calendar updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_calendar(socket, :new, calendar_params) do
    case Storage.create_calendar(calendar_params) do
      {:ok, calendar} ->
        notify_parent({:saved, calendar})

        {:noreply,
         socket
         |> put_flash(:info, "Calendar created successfully")
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
