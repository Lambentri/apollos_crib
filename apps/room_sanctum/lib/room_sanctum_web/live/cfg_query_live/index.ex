defmodule RoomSanctumWeb.QueryLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:cfg_queries, list_cfg_queries(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Query")
    |> assign(:query, Configuration.get_query!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Query")
    |> assign(:query, %Query{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg queries")
    |> assign(:query, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    query = Configuration.get_query!(id)
    {:ok, _} = Configuration.delete_query(query)

    {:noreply, assign(socket, :cfg_queries, list_cfg_queries(socket.assigns.current_user.id))}
  end

  defp list_cfg_queries(uid) do
    Configuration.list_cfg_queries({:user, uid})
  end

end
