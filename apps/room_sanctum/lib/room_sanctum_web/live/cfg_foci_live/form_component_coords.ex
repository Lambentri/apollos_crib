defmodule RoomSanctumWeb.FociLive.FormComponentCoords do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  # Exclude handle_event from SearchComponent to avoid conflicts
  import RoomSanctumWeb.SearchComponent, except: [handle_event: 3]

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  defp normalize_ll(val) do
    cond do
      val < -180 -> val + 360
      true -> val
    end
  end

  @impl true
  def update(%{foci: foci} = assigns, socket) do
    changeset = Configuration.change_foci(foci)

    # Extract coordinates if they exist
    {lat, lng} = case foci.place do
      %Geo.Point{coordinates: {lat, lng}} -> {lat, lng}
      _ -> {nil, nil}
    end

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(:latitude, lat)
      |> assign(:longitude, lng)
      |> assign(:coord_input, format_coords(lat, lng))
      |> assign_form(changeset)
    }
  end

  @impl true
  def handle_event("validate", %{"foci" => foci_params}, socket) do
    foci_params =
      inj_uid(foci_params, socket)
      |> Map.put(
        "place",
        socket.assigns
        |> Map.get(:place)
      )

    changeset =
      socket.assigns.foci
      |> Configuration.change_foci(foci_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"foci" => foci_params}, socket) do
    foci_params =
      inj_uid(foci_params, socket)
      |> Map.put(
        "place",
        socket.assigns
        |> Map.get(:place)
      )

    save_foci(socket, socket.assigns.action, foci_params)
  end

  def handle_event("coord-input-change", %{"coord-input" => value}, socket) do
    {:noreply, assign(socket, :coord_input, value)}
  end

  def handle_event("coord-input-change", _params, socket) do
    # Fallback for unexpected params format
    {:noreply, socket}
  end

  def handle_event("coord-input-keydown", %{"key" => "Enter", "value" => value}, socket) do
    handle_event("coord-update", %{"coords" => value}, socket)
  end

  def handle_event("coord-input-keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("coord-update", %{"coords" => coords_str}, socket) do
    case parse_coordinates(coords_str) do
      {:ok, {lat, lng}} ->
        lat_lng_pt = %Geo.Point{
          coordinates: {normalize_ll(lat), normalize_ll(lng)},
          srid: 4326
        }

        cs = socket.assigns.foci |> Ecto.Changeset.change(place: lat_lng_pt)

        {
          :noreply,
          socket
          |> assign(:changeset, cs)
          |> assign_form(cs)
          |> assign(:place, lat_lng_pt)
          |> assign(:latitude, lat)
          |> assign(:longitude, lng)
          |> assign(:coord_input, coords_str)
          |> put_flash(:info, "Coordinates updated: #{Float.round(lat, 6)}, #{Float.round(lng, 6)}")
        }

      {:error, reason} ->
        {
          :noreply,
          socket
          |> assign(:coord_input, coords_str)
          |> put_flash(:error, reason)
        }
    end
  end

  def handle_event("latitude-update", %{"value" => lat_str}, socket) do
    update_coordinate(socket, lat_str, socket.assigns.longitude, :latitude)
  end

  def handle_event("longitude-update", %{"value" => lng_str}, socket) do
    update_coordinate(socket, socket.assigns.latitude, lng_str, :longitude)
  end

  defp update_coordinate(socket, lat, lng, changed_field) do
    lat_val = parse_float(lat)
    lng_val = parse_float(lng)

    case {lat_val, lng_val} do
      {{:ok, lat_f}, {:ok, lng_f}} when lat_f >= -90 and lat_f <= 90 and lng_f >= -180 and lng_f <= 180 ->
        lat_lng_pt = %Geo.Point{
          coordinates: {normalize_ll(lat_f), normalize_ll(lng_f)},
          srid: 4326
        }

        cs = socket.assigns.foci |> Ecto.Changeset.change(place: lat_lng_pt)

        {
          :noreply,
          socket
          |> assign(:changeset, cs)
          |> assign_form(cs)
          |> assign(:place, lat_lng_pt)
          |> assign(:latitude, lat_f)
          |> assign(:longitude, lng_f)
          |> assign(:coord_input, format_coords(lat_f, lng_f))
        }

      {{:ok, lat_f}, _} when changed_field == :latitude ->
        {:noreply, assign(socket, :latitude, lat_f)}

      {_, {:ok, lng_f}} when changed_field == :longitude ->
        {:noreply, assign(socket, :longitude, lng_f)}

      _ ->
        {:noreply, socket}
    end
  end

  defp parse_float(nil), do: {:error, "empty"}
  defp parse_float(""), do: {:error, "empty"}
  defp parse_float(val) when is_float(val), do: {:ok, val}
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {float_val, ""} -> {:ok, float_val}
      {float_val, _} -> {:ok, float_val}
      :error -> {:error, "invalid"}
    end
  end

  # Parse various coordinate formats:
  # - "42.3736, -71.1097"
  # - "42.3736,-71.1097"
  # - "42.3736 -71.1097"
  # - "lat: 42.3736, lng: -71.1097"
  defp parse_coordinates(coords_str) when is_binary(coords_str) do
    coords_str = String.trim(coords_str)
    
    # Remove common prefixes
    coords_str = coords_str
    |> String.replace(~r/lat(itude)?:\s*/i, "")
    |> String.replace(~r/lng|lon(gitude)?:\s*/i, "")
    |> String.replace(~r/[\[\]\(\)\{\}]/, "")
    
    # Try to split by comma or space
    parts = String.split(coords_str, ~r/[,\s]+/, trim: true)
    
    case parts do
      [lat_str, lng_str] ->
        with {:ok, lat} <- parse_float(lat_str),
             {:ok, lng} <- parse_float(lng_str) do
          cond do
            lat < -90 or lat > 90 ->
              {:error, "Latitude must be between -90 and 90"}
            lng < -180 or lng > 180 ->
              {:error, "Longitude must be between -180 and 180"}
            true ->
              {:ok, {lat, lng}}
          end
        else
          {:error, _} -> {:error, "Invalid coordinate format. Use: latitude, longitude"}
        end
      
      _ ->
        {:error, "Invalid format. Enter coordinates as: latitude, longitude (e.g., 42.3736, -71.1097)"}
    end
  end

  defp format_coords(nil, _), do: ""
  defp format_coords(_, nil), do: ""
  defp format_coords(lat, lng) do
    "#{Float.round(lat, 6)}, #{Float.round(lng, 6)}"
  end

  defp save_foci(socket, :edit, foci_params) do
    case Configuration.update_foci(socket.assigns.foci, foci_params) do
      {:ok, foci} ->
        notify_parent({:saved, foci})

        {
          :noreply,
          socket
          |> put_flash(:info, "Foci updated successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_foci(socket, :edit_coords, foci_params) do
    case Configuration.update_foci(socket.assigns.foci, foci_params) do
      {:ok, foci} ->
        notify_parent({:saved, foci})

        {
          :noreply,
          socket
          |> put_flash(:info, "Foci updated successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_foci(socket, :new, foci_params) do
    case Configuration.create_foci(foci_params) do
      {:ok, foci} ->
        notify_parent({:saved, foci})

        {
          :noreply,
          socket
          |> put_flash(:info, "Foci created successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_foci(socket, :new_coords, foci_params) do
    case Configuration.create_foci(foci_params) do
      {:ok, foci} ->
        notify_parent({:saved, foci})

        {
          :noreply,
          socket
          |> put_flash(:info, "Foci created successfully")
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

  defp getlatlng(%{:place => nil}) do
    nil
  end

  defp getlatlng(%{:place => place}) do
    place |> Map.get(:coordinates, {}) |> Tuple.to_list() |> Poison.encode!()
  end
end
