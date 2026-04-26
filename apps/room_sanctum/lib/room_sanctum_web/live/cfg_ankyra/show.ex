defmodule RoomSanctumWeb.AnkyraLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RoomSanctum.PubSub, RoomSanctum.Worker.Ankyra.topic(id))
    end

    {:ok, assign(socket, :consumer_count, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:ankyra, Accounts.get_rabbit_user!(id))}
  end

  @impl true
  def handle_info({:ankyra_status, count}, socket) do
    {:noreply, assign(socket, :consumer_count, count)}
  end

  @impl true
  def handle_event("toggle-auto-register", _params, socket) do
    ankyra = socket.assigns.ankyra
    {:ok, updated} =
      Accounts.update_rabbit_user(ankyra, %{auto_register_clients: !ankyra.auto_register_clients})

    {:noreply, assign(socket, :ankyra, updated)}
  end

  def handle_event("add-client-id", %{"client_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("add-client-id", %{"client_id" => client_id}, socket) do
    ankyra = socket.assigns.ankyra
    new_list = Enum.uniq([String.trim(client_id) | ankyra.client_ids])

    case Accounts.update_rabbit_user(ankyra, %{client_ids: new_list}) do
      {:ok, updated} -> {:noreply, assign(socket, :ankyra, updated)}
      {:error, _cs} -> {:noreply, put_flash(socket, :error, "Could not add client ID")}
    end
  end

  def handle_event("remove-client-id", %{"client_id" => client_id}, socket) do
    ankyra = socket.assigns.ankyra
    new_list = Enum.reject(ankyra.client_ids, &(&1 == client_id))
    {:ok, updated} = Accounts.update_rabbit_user(ankyra, %{client_ids: new_list})
    {:noreply, assign(socket, :ankyra, updated)}
  end

  defp page_title(:show), do: "Ankyra Detail"
  defp page_title(:edit), do: "Modify Ankyra"
end
