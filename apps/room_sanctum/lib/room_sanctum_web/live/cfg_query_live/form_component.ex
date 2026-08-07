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

    sources = Configuration.list_cfg_sources({:user, assigns.current_user.id})
    focis = Configuration.list_focis({:user, assigns.current_user.id})

    current_type = type_for_source_id(sources, Map.get(query, :source_id))

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_form(changeset)
      |> assign(:changeset, changeset)
      |> assign(:tint_opts, ["amber", "lime", "emerald", "sky", "violet", "fuchsia", "rose", "stone", "slate"])
      |> assign(:cfg_sources, sources)
      |> assign(:cfg_foci, focis)
      |> assign(:current_type, current_type)
      |> assign(:treasury_groups, treasury_groups(sources, Map.get(query, :source_id)))
      |> assign(:results, [])
      |> assign(:cfg_sources_sel, Enum.into(sources, %{}, fn x -> {x.name, x.id} end))
      |> assign(:cfg_foci_sel, Enum.into(focis, %{}, fn x -> {x.name, x.id} end))
    }
  end

  @impl true
  def handle_event("validate", %{"query" => query_params}, socket) do
    query_params = inj_uid(query_params, socket)

    changeset =
      socket.assigns.query
      |> Configuration.change_query(query_params)
      |> Map.put(:action, :validate)

    current_type =
      type_for_source_id(socket.assigns.cfg_sources, parse_id(query_params["source_id"]))

    {:noreply,
     socket
     |> assign(:current_type, current_type)
     |> assign(
       :treasury_groups,
       treasury_groups(socket.assigns.cfg_sources, parse_id(query_params["source_id"]))
     )
     |> assign_form(changeset)}
  end

  # Swapping is a one-click fix for a pair entered the wrong way round -- a rate
  # of 0.0000116 usually means you wanted the reciprocal.
  def handle_event("treasury-swap", _params, socket) do
    applied = Ecto.Changeset.apply_changes(socket.assigns.form.source)
    q = applied.query

    # Rebuilt from the applied changeset rather than the stored record, so an
    # unsaved name or notes edit is not thrown away by the swap.
    params =
      %{
        "name" => applied.name,
        "notes" => applied.notes,
        "source_id" => applied.source_id,
        "query" => %{
          "__type__" => "treasury",
          "from" => query_field(q, :to),
          "to" => query_field(q, :from),
          "precision" => query_field(q, :precision)
        }
      }
      |> inj_uid(socket)

    changeset =
      socket.assigns.query
      |> Configuration.change_query(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"query" => query_params}, socket) do
    query_params = inj_uid(query_params, socket)
    save_query(socket, socket.assigns.action, query_params)
  end

  def handle_event("do-gtfs-search", %{"value" => value}, socket) do
    case value do
      nil ->
        {:noreply, socket}

      _ ->
        {:noreply,
         socket
         |> assign(:results, Storage.list_stops(get_source_id(socket.assigns.form), value))}
    end
  end

  def handle_event("do-gbfs-search", %{"value" => value}, socket) do
    case value do
      nil ->
        {:noreply, socket}

      _ ->
        {:noreply,
         socket
         |> assign(
           :results,
           Storage.list_gbfs_station_information(get_source_id(socket.assigns.form), value)
         )}
    end
  end

  def handle_event("set-gtfs", %{"val" => stop, "type" => type}, socket) do
    changeset =
      socket.assigns.query
      |> Configuration.change_query(%{
        "query" => %{"stop" => stop, "__type__" => type},
        "__type__" => type
      })
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:results, []) |> assign_form(changeset)}
  end

  def handle_event("set-gbfs", %{"val" => stop, "type" => type}, socket) do
    changeset =
      socket.assigns.query
      |> Configuration.change_query(%{
        "query" => %{"stop_id" => stop, "__type__" => type},
        "__type__" => type
      })
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:results, []) |> assign_form(changeset)}
  end

  defp save_query(socket, :edit, query_params) do
    case Configuration.update_query(socket.assigns.query, query_params) do
      {:ok, query} ->
        notify_parent({:saved, query})

        {
          :noreply,
          socket
          |> put_flash(:info, "Query updated successfully")
          |> push_patch(to: socket.assigns.patch)
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
          |> push_patch(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  # apply_changes/1 leaves an *invalid* embed as a Changeset rather than a
  # struct, so a half-filled pair -- exactly when someone reaches for swap --
  # needs reading through get_field rather than Map.get.
  defp query_field(%Ecto.Changeset{} = cs, key), do: Ecto.Changeset.get_field(cs, key)
  defp query_field(%_{} = struct, key), do: Map.get(struct, key)
  defp query_field(_, _), do: nil

  # Which groups the selected offering wants shown; anything else gets them all.
  defp treasury_groups(sources, source_id) do
    case Enum.find(List.wrap(sources), &(&1.id == source_id)) do
      %{type: :treasury, config: %RoomSanctum.Configuration.Configs.Treasury{} = cfg} ->
        RoomTreasury.Currencies.grouped(
          RoomSanctum.Configuration.Configs.Treasury.enabled_categories(cfg)
        )

      _ ->
        RoomTreasury.Currencies.grouped()
    end
  end

  defp type_for_source_id(_sources, nil), do: nil

  defp type_for_source_id(sources, id) do
    case Enum.find(sources, &(&1.id == id)) do
      nil -> nil
      s -> s.type
    end
  end

  defp parse_id(nil), do: nil
  defp parse_id(""), do: nil
  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp get_source_id(form) do
    form.source
    |> Map.get(:changes)
    |> Map.get(:source_id) ||
      form.data
      |> Map.get(:source_id)
  end
end
