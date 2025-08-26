defmodule RoomSanctumWeb.SourceLive.ImportComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Source

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:import_data, nil)
     |> assign(:parsed_sources, [])
     |> assign(:validation_results, [])}
  end

  @impl true
  def handle_event("validate_json", %{"import" => %{"json_content" => json_content}}, socket) do
    case parse_and_validate_sources(json_content, socket.assigns.current_user.id) do
      {:ok, {parsed_sources, validation_results}} ->
        {:noreply,
         socket
         |> assign(:import_data, json_content)
         |> assign(:parsed_sources, parsed_sources)
         |> assign(:validation_results, validation_results)}

      {:error, error_message} ->
        {:noreply,
         socket
         |> assign(:import_data, json_content)
         |> assign(:parsed_sources, [])
         |> assign(:validation_results, [])
         |> put_flash(:error, error_message)}
    end
  end

  @impl true
  def handle_event("import_sources", _params, socket) do
    valid_sources = 
      socket.assigns.validation_results
      |> Enum.filter(fn {_source, changeset} -> changeset.valid? end)
      |> Enum.map(fn {source, _changeset} -> source end)

    imported_count = import_valid_sources(valid_sources)
    
    notify_parent({:sources_imported, imported_count})
    
    {:noreply,
     socket
     |> put_flash(:info, "Successfully imported #{imported_count} sources")
     |> assign(:import_data, nil)
     |> assign(:parsed_sources, [])
     |> assign(:validation_results, [])}
  end

  defp parse_and_validate_sources(json_content, user_id) do
    case Poison.decode(json_content) do
      {:ok, %{"sources" => sources_data}} ->
        results = 
          sources_data
          |> Enum.with_index()
          |> Enum.map(fn {source_data, index} ->
            # Clean the source data for import
            source_attrs = 
              source_data
              |> Map.delete("id")
              |> Map.delete("inserted_at") 
              |> Map.delete("updated_at")
              |> Map.put("user_id", user_id)
              |> atomize_keys()

            # Create a changeset to validate the source
            source = %Source{}
            changeset = Configuration.change_source(source, source_attrs)
            
            {source_attrs, changeset}
          end)
        
        parsed_sources = Enum.map(results, fn {source_attrs, _changeset} -> source_attrs end)
        validation_results = results
        
        {:ok, {parsed_sources, validation_results}}

      {:ok, _} ->
        {:error, "Invalid import format. Expected JSON with 'sources' key."}

      {:error, _} ->
        {:error, "Invalid JSON format"}
    end
  end

  defp import_valid_sources(sources) do
    sources
    |> Enum.reduce(0, fn source_attrs, count ->
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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
