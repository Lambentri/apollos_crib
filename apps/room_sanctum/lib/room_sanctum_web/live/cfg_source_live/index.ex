defmodule RoomSanctumWeb.SourceLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Source

  @impl true
  def mount(_params, _session, socket) do
    sources = list_cfg_sources(socket.assigns.current_user.id)
    available_tints = get_available_tints(sources)

    {:ok,
     socket
     |> assign(:show_info, false)
     |> assign(:tint, nil)
     |> assign(:available_tints, available_tints)
     |> assign(:selected_sources, MapSet.new())
     |> assign(:export_json, nil)
     |> assign(:show_export_modal, false)
     |> assign(:cfg_sources_ids, sources |> Enum.map(fn x -> x.id end))
     |> stream(:cfg_sources, sources)

    }
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

  defp apply_action(socket, :import, _params) do
    socket
    |> assign(:page_title, "Import Offerings")
    |> assign(:source, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Offerings")
    |> assign(:source, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.SourceLive.FormComponent, {:saved, source}}, socket) do
    sources = list_cfg_sources(socket.assigns.current_user.id)
    available_tints = get_available_tints(sources)
    
    {:noreply, 
     socket
     |> assign(:available_tints, available_tints)
     |> stream_insert(:cfg_sources, source)}
  end

  @impl true
  def handle_info({RoomSanctumWeb.SourceLive.ImportComponent, {:sources_imported, count}}, socket) do
    sources = list_cfg_sources(socket.assigns.current_user.id)
    available_tints = get_available_tints(sources)
    
    {:noreply, 
     socket
     |> put_flash(:info, "Successfully imported #{count} sources")
     |> assign(:available_tints, available_tints)
     |> stream(:cfg_sources, sources, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    source = Configuration.get_source!(id)
    {:ok, _} = Configuration.delete_source(source)

    {:noreply, stream_delete(socket, :cfg_sources, source)}
  end

  def handle_event("toggle-source-enabled", %{"id" => id, "current" => current}, socket) do
    curr_bool = current |> String.to_existing_atom()
    src_og = Configuration.get_source!(id)
    {:ok, src} = Configuration.toggle_source!(id, not curr_bool)

    icon = """
    <i class="fas #{get_icon(src.type)}"></i>
    """

    {
      :noreply,
      socket
      |> stream_insert(:cfg_sources, src, at: -1)
      |> put_flash(:info, ["Toggled ", src.name, " ", raw(icon), " Successfully"])
    }
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  def handle_event("set-tint", %{"tint"=> tint}, socket) do
    IO.inspect({"set-tint", tint, socket.assigns.tint})
    case socket.assigns.tint == tint do
      true -> {:noreply, socket |> assign(:tint, nil) |> stream(:cfg_sources, list_cfg_sources(socket.assigns.current_user.id), reset: true)}
      false -> {:noreply, socket |> assign(:tint, tint) |> stream(:cfg_sources, list_cfg_sources(socket.assigns.current_user.id, tint), reset: true)}
    end
  end

  def handle_event("toggle-source-selection", %{"id" => id} = params, socket) do
    source_id = String.to_integer(id)
    IO.inspect(params, label: "checkbox params")
    # Check if the checkbox is checked by looking for the "value" key
    is_checked = Map.has_key?(params, "value")
    
    selected_sources = case is_checked do
      true -> MapSet.put(socket.assigns.selected_sources, source_id)
      false -> MapSet.delete(socket.assigns.selected_sources, source_id)
    end
    IO.inspect(selected_sources, label: "updated selection")
    {:noreply, assign(socket, :selected_sources, selected_sources)}
  end

  def handle_event("toggle-all-selection", _params, socket) do
    # Get all source IDs from the stream
    all_source_ids = 
      socket.assigns.cfg_sources_ids

    IO.inspect(all_source_ids)
    IO.inspect(MapSet.size(socket.assigns.selected_sources) )
    
    selected_sources = case MapSet.size(socket.assigns.selected_sources) do
      0 -> MapSet.new(all_source_ids ) # Select all
      _ -> MapSet.new()    # Deselect all
    end

    IO.inspect(selected_sources, label: "SELSEOURCE")
    
    {:noreply, assign(socket, :selected_sources, selected_sources)}
  end

  def handle_event("export-sources", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_sources)
    sources = Enum.map(selected_ids, &Configuration.get_source!/1)
    
    # Clean sources by removing unwanted fields
    cleaned_sources = Enum.map(sources, &clean_source_for_export/1)
    
    export_data = %{
      exported_at: DateTime.utc_now(),
      sources: cleaned_sources
    }
    
    json_data = Poison.encode!(export_data, pretty: true)
    
    {:noreply, 
     socket
     |> assign(:export_json, json_data)
     |> assign(:show_export_modal, true)}
  end

  def handle_event("close-export-modal", _params, socket) do
    {:noreply, 
     socket
     |> assign(:export_json, nil)
     |> assign(:show_export_modal, false)}
  end

  def handle_event("import-sources", _params, socket) do
    {:noreply, push_event(socket, "upload_file", %{})}
  end

  def handle_event("process-import", %{"file_data" => file_data}, socket) do
    case Poison.decode(file_data) do
      {:ok, %{"sources" => sources_data}} ->
        imported_count = import_sources(sources_data, socket.assigns.current_user.id)
        {:noreply, 
         socket
         |> put_flash(:info, "Successfully imported #{imported_count} sources")
         |> stream(:cfg_sources, list_cfg_sources(socket.assigns.current_user.id), reset: true)}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid import file format")}
    end
  end

  defp list_cfg_sources(uid) do
    Configuration.list_cfg_sources({:user, uid})
  end

  defp list_cfg_sources(uid, tint) do
    Configuration.list_cfg_sources({:user, uid}) |> Enum.filter(fn s -> 
      s.meta && s.meta.tint == tint 
    end)
  end

  defp get_available_tints(sources) do
    sources
    |> Enum.filter_map(&(&1.meta && &1.meta.tint), &(&1.meta.tint))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp import_sources(sources_data, user_id) do
    sources_data
    |> Enum.reduce(0, fn source_data, count ->
      # Remove id and timestamps to let database generate new ones
      source_attrs = 
        source_data
        |> Map.delete("id")
        |> Map.delete("inserted_at")
        |> Map.delete("updated_at")
        |> Map.put("user_id", user_id)
        |> atomize_keys()

      case Configuration.create_source(source_attrs) do
        {:ok, _source} -> count + 1
        {:error, _changeset} -> count
      end
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, atomize_keys(v)}
    end)
    |> Enum.into(%{})
  rescue
    ArgumentError -> map  # If atom doesn't exist, keep as string
  end

  defp atomize_keys(value), do: value

  defp clean_source_for_export(source) do
    # Add the type field to the config map for import compatibility
    updated_config = 
      case source.config do
        %{} = config when is_map(config) -> Map.put(config, :__type__, source.type)
        config -> config
      end

    source
    |> Map.drop([:__meta__, :mailboxes, :webhooks, :user])
    |> Map.drop(["__meta__", "mailboxes", "webhooks", "user"])
    |> Map.put(:config, updated_config)
  end

  defp get_icon(source_type) do
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

      :cronos ->
        "fa-clock"

      :gitlab ->
        "fa-code-branch"

      :packages ->
        "fa-envelopes-bulk"
    end
  end

  def all_selected(list, selected) do
    cond do
      selected |> MapSet.size == 0 -> :false
      list.inserts |> length == selected |> MapSet.size -> "true"
      true -> :false
    end
  end
end
