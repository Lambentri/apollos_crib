defmodule RoomSanctumWeb.QueryLive.Index do
  use RoomSanctumWeb, :live_view_a
  import RoomSanctumWeb.Components.QueryGeospatialMap

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Query

  @impl true
  def mount(_params, _session, socket) do
    queries = list_cfg_queries(socket.assigns.current_user.id)
    available_tints = get_available_tints(queries)

    {:ok,
     socket
     |> assign(:show_info, false)
     |> assign(:tint, nil)
     |> assign(:view_mode, :table)
     |> assign(:available_tints, available_tints)
     |> assign(:queries, queries)
     |> stream(:cfg_queries, queries)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Modify Query")
    |> assign(:query, Configuration.get_query!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Make a Query")
    |> assign(:query, %Query{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Available Queries")
    |> assign(:query, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.QueryLive.FormComponent, {:saved, query}}, socket) do
    queries = list_cfg_queries(socket.assigns.current_user.id)
    available_tints = get_available_tints(queries)
    
    {:noreply, 
     socket
     |> assign(:available_tints, available_tints)
     |> assign(:queries, queries)
     |> stream_insert(:cfg_queries, query)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    query = Configuration.get_query!(id)
    {:ok, _} = Configuration.delete_query(query)

    {:noreply, stream_delete(socket, :cfg_queries, query)}
  end

  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  def handle_event("toggle-view", _params, socket) do
    new_mode = case socket.assigns.view_mode do
      :table -> :map
      :map -> :table
    end
    
    {:noreply, socket |> assign(:view_mode, new_mode)}
  end

  def handle_event("set-tint", %{"tint"=> tint}, socket) do
    IO.inspect({"set-tint", tint, socket.assigns.tint})
    queries = case socket.assigns.tint == tint do
      true -> 
        list_cfg_queries(socket.assigns.current_user.id)
      false -> 
        list_cfg_queries(socket.assigns.current_user.id, tint)
    end
    
    new_tint = if socket.assigns.tint == tint, do: nil, else: tint
    
    {:noreply, socket 
     |> assign(:tint, new_tint) 
     |> assign(:queries, queries)
     |> stream(:cfg_queries, queries, reset: true)}
  end

  defp list_cfg_queries(uid) do
    Configuration.list_cfg_queries({:user, uid})
  end

  defp list_cfg_queries(uid, tint) do
    Configuration.list_cfg_queries({:user, uid}) |> Enum.filter(fn q -> 
      (q.meta && q.meta.tint == tint) || (q.source && q.source.meta && q.source.meta.tint == tint)
    end)
  end

  defp get_available_tints(queries) do
    queries
    |> Enum.flat_map(fn query ->
      tints = []
      
      # Add query tint if it exists
      tints = if query.meta && query.meta.tint do
        [query.meta.tint | tints]
      else
        tints
      end
      
      # Add source tint if it exists  
      tints = if query.source && query.source.meta && query.source.meta.tint do
        [query.source.meta.tint | tints]
      else
        tints
      end
      
      tints
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end
end
