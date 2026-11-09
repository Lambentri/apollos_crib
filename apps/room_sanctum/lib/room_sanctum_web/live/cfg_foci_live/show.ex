defmodule RoomSanctumWeb.FociLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @foci_source_types [:aqi, :calendar, :ephem, :weather, :cronos]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    foci = Configuration.get_foci!(owner(socket), id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:foci, foci)
     |> assign_query_data(foci)}
  end

  @impl true
  def handle_event("create-queries-for-sources", params, socket) do
    source_ids =
      params
      |> Map.get("source_ids", [])
      |> Enum.map(&String.to_integer/1)

    foci = socket.assigns.foci
    existing = socket.assigns.existing_queries_by_source

    # Only sources the page offered -- the user's own, of a foci type. The ids
    # are the client's, and any other is skipped rather than looked up.
    offered = Map.new(socket.assigns.foci_sources, &{&1.id, &1})

    results =
      source_ids
      |> Enum.reject(&Map.has_key?(existing, &1))
      |> Enum.map(&Map.get(offered, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&create_foci_query(&1, foci))

    count = Enum.count(results, fn {status, _} -> status == :ok end)

    flash =
      case count do
        0 -> "No queries created"
        1 -> "Created 1 query"
        n -> "Created #{n} queries"
      end

    {:noreply,
     socket
     |> put_flash(:info, flash)
     |> assign_query_data(foci)}
  end

  defp create_foci_query(source, foci) do
    type_str = Atom.to_string(source.type)

    Configuration.create_query(%{
      user_id: foci.user_id,
      source_id: source.id,
      name: foci.name,
      query: Map.put(default_query_for(source.type, foci.id), "__type__", type_str),
      public: true
    })
  end

  defp default_query_for(:aqi, foci_id), do: %{"foci_id" => foci_id}
  defp default_query_for(:ephem, foci_id), do: %{"foci_id" => foci_id}
  defp default_query_for(:weather, foci_id), do: %{"foci_id" => foci_id}

  defp default_query_for(:calendar, foci_id),
    do: %{"foci_id" => foci_id, "days" => 7, "limit" => 50}

  defp default_query_for(:cronos, foci_id),
    do: %{"foci_id" => foci_id, "modulo" => 1, "offset" => 0, "period" => "day"}

  defp assign_query_data(socket, foci) do
    sources =
      Configuration.list_cfg_sources({:user, foci.user_id})
      |> Enum.filter(&(&1.type in @foci_source_types))
      |> Enum.sort_by(&{&1.type, &1.name})

    existing =
      Configuration.list_cfg_queries({:user, foci.user_id})
      |> Enum.filter(fn q ->
        case q.query do
          %{foci_id: fid} -> fid == foci.id
          _ -> false
        end
      end)
      |> Map.new(fn q -> {q.source_id, q} end)

    socket
    |> assign(:foci_sources, sources)
    |> assign(:existing_queries_by_source, existing)
  end

  defp page_title(:show), do: "Foci Detail"
  defp page_title(:edit), do: "Modify Foci"

  defp getlatlng(%{:place => nil}) do
    nil
  end

  defp getlatlng(%{:place => place}) do
    place |> Map.get(:coordinates, {}) |> Tuple.to_list() |> RoomSanctum.JSON.encode!()
  end

  # The foci comes from the URL, so it is looked up among the user's own.
  defp owner(socket), do: {:user, socket.assigns.current_user.id}
end
