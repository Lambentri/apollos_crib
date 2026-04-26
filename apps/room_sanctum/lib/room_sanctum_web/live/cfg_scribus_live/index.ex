defmodule RoomSanctumWeb.ScribusLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Scribus
  alias RoomSanctum.Configuration.ScribusResolution

  @impl true
  def mount(_params, _session, socket) do
    uid = socket.assigns.current_user.id

    {:ok,
     socket
     |> stream(:cfg_scribus, Configuration.list_cfg_scribus())
     |> stream(:resolutions, Configuration.list_scribus_resolutions({:user, uid}))
     |> assign(:show_info, false)
     |> assign(:resolution_form, to_form(Configuration.change_scribus_resolution(%ScribusResolution{})))
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Scribus")
    |> assign(:scribus, Configuration.get_scribus!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Scribus")
    |> assign(:scribus, %Scribus{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg scribus")
    |> assign(:scribus, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.ScribusLive.FormComponent, {:saved, scribus}}, socket) do
    {:noreply, stream_insert(socket, :cfg_scribus, scribus)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scribus = Configuration.get_scribus!(id)
    {:ok, _} = Configuration.delete_scribus(scribus)

    {:noreply, stream_delete(socket, :cfg_scribus, scribus)}
  end
  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  def handle_event("add-resolution", %{"scribus_resolution" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case Configuration.create_scribus_resolution(params) do
      {:ok, resolution} ->
        {:noreply,
         socket
         |> stream_insert(:resolutions, resolution)
         |> assign(:resolution_form, to_form(Configuration.change_scribus_resolution(%ScribusResolution{})))}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :resolution_form, to_form(cs))}
    end
  end

  def handle_event("delete-resolution", %{"id" => id}, socket) do
    resolution = Configuration.get_scribus_resolution!(id)

    if resolution.user_id == socket.assigns.current_user.id do
      {:ok, _} = Configuration.delete_scribus_resolution(resolution)
      {:noreply, stream_delete(socket, :resolutions, resolution)}
    else
      {:noreply, socket}
    end
  end
end
