defmodule RoomSanctumWeb.QueryLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration
  alias RoomSanctum.Storage

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  @impl true
  def update(%{query: query} = assigns, socket) do
    changeset = Configuration.change_query(query)

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_form(changeset)
      |> assign(:changeset, changeset)
      |> assign(:tint_opts, ["amber", "lime", "emerald", "sky", "violet", "fuschia", "rose", "stone", "slate"])
      |> assign(:cfg_sources, list_cfg_sources(assigns.current_user.id))
      |> assign(:cfg_foci, list_cfg_foci(assigns.current_user.id))
      |> assign(:results, [])
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

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"query" => query_params}, socket) do
    query_params = inj_uid(query_params, socket)
    save_query(socket, socket.assigns.action, query_params)
  end

  def handle_event("do-gtfs-search", %{"value" => value}, socket) do
    case value do
      nil -> {:noreply, socket}
      _otherwise -> {:noreply, socket |> assign(:results, Storage.list_stops(get_source_id(socket.assigns.form), value))}
    end
  end

    def handle_event("do-gbfs-search", %{"value" => value}, socket) do
    case value do
      nil -> {:noreply, socket}
      _otherwise -> {:noreply, socket |> assign(:results, Storage.list_gbfs_station_information(get_source_id(socket.assigns.form), value))}
    end
  end

  def handle_event("set-gtfs", %{"val" => stop, "type" => type}, socket) do
      IO.inspect(socket.assigns.query)
      changeset =
      socket.assigns.query
      |> Configuration.change_query(%{"query" => %{"stop" => stop, "__type__" => type}, "__type__" => type})
      |> Map.put(:action, :validate)
      |> IO.inspect
    IO.inspect(changeset.data)
    {:noreply, socket |> assign(:results, []) |>  assign_form(changeset)}
  end

  def handle_event("set-gbfs", %{"val" => stop, "type" => type}, socket) do
    IO.inspect(socket.assigns.query)
    changeset =
      socket.assigns.query
      |> Configuration.change_query(%{"query" => %{"stop_id" => stop, "__type__" => type}, "__type__" => type})
      |> Map.put(:action, :validate)
      |> IO.inspect
    IO.inspect(changeset.data)
    {:noreply, socket |> assign(:results, []) |>  assign_form(changeset)}
  end

  defp save_query(socket, :edit, query_params) do
    case Configuration.update_query(socket.assigns.query, query_params) do
      {:ok, query} ->
        notify_parent({:saved, query})

        {
          :noreply,
          socket
          |> put_flash(:info, "Query updated successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_query(socket, :new, query_params) do
    case Configuration.create_query(query_params) do
      {:ok, query} ->
        notify_parent({:saved, query})

        {
          :noreply,
          socket
          |> put_flash(:info, "Query created successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp list_cfg_sources(uid) do
    Configuration.list_cfg_sources({:user, uid})
  end

  defp list_cfg_foci(uid) do
    Configuration.list_focis({:user, uid})
  end

  defp  get_source_id(form) do
      form.source
      |> Map.get(:changes)
      |> Map.get(:source_id) ||
        form.data
        |> Map.get(:source_id)
  end
  defp get_current_type(form) do
    id = get_source_id(form)

    case id do
      nil ->
        :ok

      _ ->
        s = Configuration.get_source!(id)
        s.type
    end
  end
end
