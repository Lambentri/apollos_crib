defmodule RoomSanctumWeb.QueryLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  @impl true
  def update(%{query: query, current_user: current_user} = assigns, socket) do
    changeset = Configuration.change_query(query)

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)
      |> assign(:cfg_sources, list_cfg_sources(assigns.current_user.id))
      |> assign(:cfg_foci, list_cfg_foci(assigns.current_user.id))
      |> assign(
        :cfg_sources_sel,
        list_cfg_sources(assigns.current_user.id)
        |> Enum.map(fn x -> {x.name, x.id} end)
        |> Enum.into(%{})
      )
      |> assign(
        :cfg_foci_sel,
        list_cfg_foci(assigns.current_user.id)
        |> Enum.map(fn x -> {x.name, x.id} end)
        |> Enum.into(%{})
      )
    }
  end

  @impl true
  def handle_event("validate", %{"query" => query_params}, socket) do
    query_params = inj_uid(query_params, socket)

    changeset =
      socket.assigns.query
      |> Configuration.change_query(query_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"query" => query_params}, socket) do
    query_params = inj_uid(query_params, socket)
    save_query(socket, socket.assigns.action, query_params)
  end

  defp save_query(socket, :edit, query_params) do
    case Configuration.update_query(socket.assigns.query, query_params) do
      {:ok, _query} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Query updated successfully")
          |> push_redirect(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_query(socket, :new, query_params) do
    case Configuration.create_query(query_params) do
      {:ok, _query} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Query created successfully")
          |> push_redirect(to: socket.assigns.return_to)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp list_cfg_sources(uid) do
    Configuration.list_cfg_sources({:user, uid})
  end

  defp list_cfg_foci(uid) do
    Configuration.list_focis({:user, uid})
  end

  defp get_current_type(changeset) do
    id =
      changeset.changes
      |> Map.get(:source_id) ||
        changeset.data
        |> Map.get(:source_id)

    case id do
      nil ->
        :ok

      _ ->
        s = Configuration.get_source!(id)
        s.type
    end
  end
end
