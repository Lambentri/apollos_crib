defmodule RoomSanctumWeb.PlaniLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    # The anchor is not broadcast -- it is resolved on the worker's own tick
    # and held there -- so the page asks, rather than waiting to be told.
    if connected?(socket), do: :timer.send_interval(5_000, self(), :look)

    {:ok, socket |> assign(:anchor, nil) |> assign(:state, %{data: %{}, queries: []})}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Plani")
     |> assign(:plani, Configuration.get_plani!(id))
     |> assign(:sources, Configuration.list_cfg_sources({:user, socket.assigns.current_user.id}))
     |> look()}
  end

  @impl true
  def handle_info(:look, socket), do: {:noreply, look(socket)}

  defp look(socket) do
    id = to_string(socket.assigns.plani.id)

    socket
    |> assign(:anchor, RoomSanctum.Worker.Plani.where(id))
    |> assign(:state, RoomSanctum.Worker.Plani.get_state(id))
  end

  @doc "A point as something readable, or nil."
  def coordinates(%{anchor: %Geo.Point{coordinates: {lon, lat}}}) do
    "#{Float.round(lat, 5)}, #{Float.round(lon, 5)}"
  end

  def coordinates(_), do: nil

  @doc "A source's name, for a page that would otherwise show a number."
  def source_name(sources, id) do
    case Enum.find(sources, &(&1.id == id)) do
      nil -> "source #{id}"
      source -> source.name
    end
  end

  @doc "How many results a source came back with."
  def count_for(state, source_id) do
    state.data
    |> Enum.find(fn {{id, _type}, _rows} -> id == source_id end)
    |> case do
      {_key, rows} -> length(rows)
      nil -> nil
    end
  end
end
