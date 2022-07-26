defmodule RoomSanctumWeb.SourceLive.Show do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:status, :idle)
      |> assign(:status_val, 0)
      |> assign(:stats, [])
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    source = Configuration.get_source!(id)

    case source.type do
      :gtfs -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gtfs")
      :gbfs -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "gbfs")
      :aqi -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "aqi")
      :calendar -> Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "ical")
      _default -> :ok
    end

    {
      :noreply,
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:source, source)
      |> assign(
           :source_id,
           id
           |> String.to_integer()
         )
    }
  end

  defp page_title(:show), do: "Offering Detail"
  defp page_title(:edit), do: "Modify Offering"

  def handle_event("do-update", %{"type" => type, "id" => id}, socket) do
    id = id
         |> String.to_integer()

    case type do
      "gtfs" ->
        RoomGtfs.Worker.update_static_data(id)

      "gbfs" ->
        RoomGbfs.Worker.update_static_data(id)

      "aqi" ->
        RoomAirQuality.Worker.update_static_data(id)

      "ical" ->
        RoomCalendar.Worker.update_static_data(id)
    end

    {:noreply, socket}
  end

  def handle_event("do-status", _params, socket) do
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      "gtfs",
      {:gtfs, socket.assigns.source_id, :alerts, 1, 3}
    )

    {:noreply, socket}
  end

  def handle_event("do-stats", %{"type" => type, "id" => id}, socket) do
    IO.puts("calc")

    {
      :noreply,
      socket
      |> assign(:stats, socket.assigns.stats ++ ["1", "2", "3", "4", "5"])
    }
  end

  defp percent(num, denom) do
    (num / denom * 100)
    |> Float.floor()
  end

  def handle_info({:gbfs, id, file, message} = info, socket) do
    {
      :noreply,
      socket
      |> assign(:status, message)
    }
  end

  def handle_info({:gbfs, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id == id
                                   |> String.to_integer() do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:gtfs, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id == id
                                   |> String.to_integer() do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:aqi, id, file, complete, total} = info, socket) do
    if socket.assigns.source_id == id
                                   |> String.to_integer() do
      gen_pct(file, complete, total, socket)
    else
      {:noreply, socket}
    end
  end

  def gen_pct(file, complete, total, socket) do
    case file do
      :downloading ->
        {
          :noreply,
          socket
          |> assign(:status, "Retrieving Bundle")
          |> assign(:status_val, percent(complete, total))
        }

      :parsing ->
        {
          :noreply,
          socket
          |> assign(:status, "Parsing Bundle")
          |> assign(:status_val, percent(complete, total))
        }

      :extracting ->
        {
          :noreply,
          socket
          |> assign(:status, "Extracting Bundle")
          |> assign(:status_val, percent(complete, total))
        }

      :error ->
        {
          :noreply,
          socket
          |> assign(:status, "Error downloading/extracting the bundle specified")
          |> assign(:status_val, 0)
        }

      _ ->
        case complete == total do
          true ->
            status = :idle

            {
              :noreply,
              socket
              |> assign(:status, status)
              |> assign(:status_val, 0)
            }

          false ->
            status = "File: '#{file}'"

            {
              :noreply,
              socket
              |> assign(:status, status)
              |> assign(:status_val, percent(complete, total))
            }
        end
    end
  end

  defp icon(source_type) do
    case source_type do
      :calendar ->
        "fa-calendar-alt"
      :rideshare ->
        "fa-taxi"
      :hass ->
        "fa-home"
      :gtfs ->
        "fa-bus-alt"
      :gbfs ->
        "fa-bicycle"
      :tidal ->
        "fa-water"
      :ephem ->
        "fa-moon"
      :weather ->
        "fa-cloud-sun"
      :aqi ->
        "fa-lungs"
    end
  end

  defp icon_code(source_type) do
    case source_type do
      :calendar ->
        "f073"
      :rideshare ->
        "f1ba"
      :hass ->
        "f015"
      :gtfs ->
        "f55e"
      :gbfs ->
        "f206"
      :tidal ->
        "f773"
      :ephem ->
        "f186"
      :weather ->
        "f6c4"
      :aqi ->
        "f604"
    end
  end
end
