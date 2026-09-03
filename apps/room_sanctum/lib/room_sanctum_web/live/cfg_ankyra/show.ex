defmodule RoomSanctumWeb.AnkyraLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RoomSanctum.PubSub, RoomSanctum.Worker.Ankyra.topic(id))
    end

    {:ok,
     socket
     |> assign(:consumer_count, nil)
     |> assign(:connected_client_ids, [])
     |> assign(:positions, [])
     |> assign(:broker, default_broker())}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:ankyra, Accounts.get_rabbit_user!(id))
     |> then(&assign_pairing(&1, &1.assigns.broker))}
  end

  @impl true
  # Where the clients on this Ankyra say they are, newest first. The worker
  # holds these for five minutes and sends the list again as they age out, so
  # the page empties itself without needing a timer of its own.
  def handle_info({:ankyra_positions, positions}, socket) do
    {:noreply, assign(socket, :positions, positions)}
  end

  def handle_info({:ankyra_status, nil}, socket) do
    # The broker could not be asked. Say nothing rather than report an empty
    # room -- the badge draws nil as "checking".
    {:noreply,
     socket
     |> assign(:consumer_count, nil)
     |> assign(:connected_client_ids, [])}
  end

  def handle_info({:ankyra_status, %{count: count, client_ids: client_ids}}, socket) do
    {:noreply,
     socket
     |> assign(:consumer_count, count)
     |> assign(:connected_client_ids, client_ids)}
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

  # The broker's address is not the app's: the phone reaches RabbitMQ directly,
  # and where that is depends on how the cluster is exposed. Configured where
  # it is known, corrected here where it is not, without a deploy.
  def handle_event("set-broker", %{"host" => host, "port" => port} = params, socket) do
    broker = %{
      host: String.trim(host),
      port: parse_port(port),
      tls: params["tls"] == "on"
    }

    {:noreply, assign_pairing(socket, broker)}
  end

  # A client that auto-registers after this page was rendered is connected and
  # allowed, but the copy of the allow-list in the socket predates it. Drawing
  # it anyway beats a client that is plainly attached and nowhere on screen.
  def unregistered_connected(ankyra, connected_client_ids) do
    connected_client_ids -- (ankyra.client_ids || [])
  end

  defp assign_pairing(socket, broker) do
    uri = pairing_uri(socket.assigns.ankyra, broker)

    socket
    |> assign(:broker, broker)
    |> assign(:pairing_uri, uri)
    |> assign(:pairing_qr, qr_svg(uri))
  end

  @doc """
  Everything a client needs to subscribe, as one link.

  A custom scheme rather than a payload the app has to be pointed at: the
  phone's own camera resolves it, so pairing is scan-and-open with no scanner
  in the client and no five fields retyped by hand.
  """
  def pairing_uri(ankyra, broker) do
    query =
      URI.encode_query(%{
        "host" => broker.host,
        "port" => broker.port,
        "user" => ankyra.username,
        "pass" => ankyra.password,
        "topic" => ankyra.topic,
        "tls" => if(broker.tls, do: "1", else: "0")
      })

    "apolloscrib://ankyra?" <> query
  end

  defp qr_svg(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(background_color: "#ffffff", color: "#000000", viewbox: true)
    |> strip_xml_prolog()
  end

  # eqrcode writes a standalone SVG document, prolog and all. Inline in HTML
  # that prolog is not markup, and browsers render it as text above the code.
  defp strip_xml_prolog(svg) do
    String.replace(svg, ~r/\A\s*<\?xml[^>]*\?>\s*/, "")
  end

  defp default_broker do
    configured = Application.get_env(:room_sanctum, :mqtt, [])

    %{
      # The app's own hostname is the best guess available and is right
      # whenever the broker sits behind the same name.
      host: Keyword.get(configured, :host) || endpoint_host(),
      port: Keyword.get(configured, :port, 1883),
      tls: Keyword.get(configured, :tls, false)
    }
  end

  defp endpoint_host do
    RoomSanctumWeb.Endpoint.config(:url)[:host] || "localhost"
  end

  defp parse_port(port) do
    case Integer.parse(to_string(port)) do
      {n, _} when n > 0 and n < 65_536 -> n
      _ -> 1883
    end
  end

  @doc """
  How stale a fix is, as a fraction: 1.0 just arrived, 0.0 about to go.

  Drives the opacity, so a trail fades rather than blinking out. The floor
  keeps the oldest one readable right up until it is dropped.
  """
  def freshness(%{at: at}, ttl_s \\ 300) do
    age = DateTime.diff(DateTime.utc_now(), at, :second)
    ((ttl_s - age) / ttl_s) |> max(0.0) |> min(1.0) |> then(&(0.25 + 0.75 * &1))
  end

  @doc "How long ago a fix arrived, in words."
  def age_in_words(%{at: at}) do
    case DateTime.diff(DateTime.utc_now(), at, :second) do
      s when s < 5 -> "just now"
      s when s < 60 -> "#{s}s ago"
      s -> "#{div(s, 60)}m ago"
    end
  end

  defp page_title(:show), do: "Ankyra Detail"
  defp page_title(:edit), do: "Modify Ankyra"
end
