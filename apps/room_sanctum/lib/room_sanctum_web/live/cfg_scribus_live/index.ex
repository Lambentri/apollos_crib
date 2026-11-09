defmodule RoomSanctumWeb.ScribusLive.Index do
  use RoomSanctumWeb, :live_view_a

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Scribus
  alias RoomSanctum.Accounts
  alias RoomSanctum.Mutants

  # While a resolution is starting, re-read until it settles.
  @refresh_ms 5_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:cfg_scribus, Configuration.list_cfg_scribus())
     |> assign(:show_info, false)
     |> assign(:admin?, Accounts.admin?(socket.assigns.current_user))
     |> assign(:resolution_form, blank_resolution_form())
     |> load_resolutions()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Scribus")
    |> assign(:scribus, Configuration.get_scribus!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Scribus")
    |> assign(:scribus, %Scribus{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Cfg scribus")
    |> assign(:scribus, nil)
  end

  @impl true
  def handle_info({RoomSanctumWeb.ScribusLive.FormComponent, {:saved, scribus}}, socket) do
    {:noreply, stream_insert(socket, :cfg_scribus, scribus)}
  end

  def handle_info(:refresh_resolutions, socket) do
    {:noreply, load_resolutions(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scribus = Configuration.get_scribus!(id)
    {:ok, _} = Configuration.delete_scribus(scribus)

    {:noreply, stream_delete(socket, :cfg_scribus, scribus)}
  end
  def handle_event("info", _params, socket) do
    {:noreply, socket |> assign(:show_info, !socket.assigns.show_info)}
  end

  def handle_event("refresh-resolutions", _params, socket) do
    {:noreply, load_resolutions(socket)}
  end

  def handle_event("add-resolution", %{"resolution" => params}, %{assigns: %{admin?: true}} = socket) do
    with {:ok, width} <- parse_int(params["width"]),
         {:ok, height} <- parse_int(params["height"]),
         {:ok, instances} <- parse_int(params["instances"]),
         {:ok, label} <- Mutants.create_resolution(params["name"] || "", width, height, instances) do
      {:noreply,
       socket
       |> put_flash(:info, "Starting resolution #{label} (#{width}x#{height})")
       |> assign(:resolution_form, blank_resolution_form())
       |> load_resolutions()}
    else
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg) |> assign(:resolution_form, to_form(params, as: :resolution))}
    end
  end

  def handle_event("delete-resolution", %{"label" => label}, %{assigns: %{admin?: true}} = socket) do
    socket =
      case Mutants.delete_resolution(label) do
        :ok -> put_flash(socket, :info, "Stopped resolution #{label}")
        {:error, msg} -> put_flash(socket, :error, msg)
      end

    {:noreply, load_resolutions(socket)}
  end

  # The buttons are only rendered for admins; this covers a crafted event.
  def handle_event(event, _params, socket) when event in ["add-resolution", "delete-resolution"] do
    {:noreply, put_flash(socket, :error, "Only admins can change resolutions")}
  end

  defp load_resolutions(socket) do
    case Mutants.list_resolutions() do
      {:ok, list} ->
        if connected?(socket) and Enum.any?(list, &(&1.state == "Progressing")),
          do: Process.send_after(self(), :refresh_resolutions, @refresh_ms)

        socket |> assign(:resolutions, list) |> assign(:resolutions_error, nil)

      {:error, msg} ->
        socket |> assign(:resolutions, []) |> assign(:resolutions_error, msg)
    end
  end

  defp blank_resolution_form,
    do: to_form(%{"name" => "", "width" => "", "height" => "", "instances" => "1"}, as: :resolution)

  defp parse_int(value) do
    case Integer.parse(to_string(value)) do
      {n, ""} when n > 0 -> {:ok, n}
      _ -> {:error, "width, height and instances must be positive whole numbers"}
    end
  end
end
