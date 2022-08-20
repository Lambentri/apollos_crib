defmodule RoomSanctumWeb.SourceLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Source

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:cfg_sources, list_cfg_sources(socket.assigns.current_user.id)) |> assign(:show_info, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Offering")
    |> assign(:source, Configuration.get_source!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Submit Offering")
    |> assign(:source, %Source{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Offerings")
    |> assign(:source, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    source = Configuration.get_source!(id)
    {:ok, _} = Configuration.delete_source(source)

    {:noreply, assign(socket, :cfg_sources, list_cfg_sources(socket.assigns.current_user.id))}
  end

  def handle_event("toggle-source-enabled", %{"id" => id, "current" => current}, socket) do
    curr_bool = current
                |> String.to_existing_atom
    {:ok, src} = Configuration.toggle_source!(id, not curr_bool)
    icon = """
    <i class="fas #{icon(src.type)}"></i>
    """
    {
      :noreply,
      socket
      |> assign(:cfg_sources, list_cfg_sources(socket.assigns.current_user.id))
      |> put_flash(:info, ["Toggled ", src.name, " ", raw(icon), " Successfully"])
    }
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  defp list_cfg_sources(uid) do
    Configuration.list_cfg_sources({:user, uid})
  end

  defp icon(source_type) do
    case source_type do
      :calendar ->
        "fa-calendar-alt"
      :rideshare ->
        "fa-taxi"
      :hass ->
        "fa-home"
      :gtfs ->
        "fa-bus-alt"
      :gbfs ->
        "fa-bicycle"
      :tidal ->
        "fa-water"
      :ephem ->
        "fa-moon"
      :weather ->
        "fa-cloud-sun"
      :aqi ->
        "fa-lungs"
    end
  end

end
