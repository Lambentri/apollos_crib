defmodule RoomSanctumWeb.Components.LeafletMapComponent do
  @moduledoc """
  Leaflet Map Web Component for Phoenix LiveView
  
  This component provides a declarative way to render Leaflet maps using Web Components
  instead of hooks. It maintains high performance with canvas rendering and streaming
  capabilities while providing a more maintainable structure.
  """
  
  use Phoenix.Component

  @doc """
  Renders a Leaflet map using Web Components
  
  ## Examples

      <.leaflet_map lat="39.8283" lng="-98.5795" zoom="4" class="h-96">
        <.leaflet_marker 
          lat="40.7589" 
          lng="-73.9851" 
          name="New York" 
          type="query"
          tint="blue"
          id="nyc"
          phx-click="marker_clicked"
          phx-value-id="nyc" />
      </.leaflet_map>

  ## Attributes

    * `lat` - Initial latitude (default: 39.8283)
    * `lng` - Initial longitude (default: -98.5795)
    * `zoom` - Initial zoom level (default: 4)
    * `use_streaming` - Enable streaming mode (default: false)
    * `class` - CSS classes to apply to the map container
    * `style` - Inline styles for the map container

  """
  attr :lat, :string, default: "39.8283"
  attr :lng, :string, default: "-98.5795"
  attr :zoom, :string, default: "4"
  attr :use_streaming, :boolean, default: false
  attr :class, :string, default: ""
  attr :style, :string, default: ""
  attr :id, :string, default: ""
  slot :inner_block, required: false
  def leaflet_map(assigns) do
    ~H"""
    <leaflet-map 
      id={@id}
      lat={@lat} 
      lng={@lng} 
      zoom={@zoom}
      zoom={@zoom}
      use-streaming={to_string(@use_streaming)}
      class={@class}
      style={@style}
    >
      <%= render_slot(@inner_block) %>
    </leaflet-map>
    """
  end

  @doc """
  Renders a marker for the Leaflet map
  
  ## Examples

      <.leaflet_marker 
        lat="40.7589" 
        lng="-73.9851" 
        name="New York" 
        type="query"
        tint="blue" />

  ## Attributes

    * `lat` - Marker latitude (required)
    * `lng` - Marker longitude (required)
    * `name` - Display name for the marker
    * `type` - Marker type: "query", "vehicle", "free-bike", "station"
    * `tint` - Color tint for the marker
    * `id` - Unique identifier
    * `vehicle_id` - Vehicle ID (for vehicle markers)
    * `route_id` - Route ID (for vehicle markers)
    * `selected` - Whether marker is selected (boolean)

  """
  attr :lat, :string, required: true
  attr :lng, :string, required: true
  attr :name, :string, default: ""
  attr :type, :string, default: "query"
  attr :tint, :string, default: ""
  attr :id, :string, default: ""
  attr :vehicle_id, :string, default: ""
  attr :route_id, :string, default: ""
  attr :selected, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-id phx-target)
  slot :inner_block, required: false

  def leaflet_marker(assigns) do
    ~H"""
    <leaflet-marker 
      lat={@lat}
      lng={@lng}
      name={@name}
      type={@type}
      tint={@tint}
      id={@id}
      vehicle-id={@vehicle_id}
      route-id={@route_id}
      selected={to_string(@selected)}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </leaflet-marker>
    """
  end

  @doc """
  Renders an icon for a marker
  
  ## Examples

      <.leaflet_icon icon_url="/images/marker.png" width="32" height="32" />

  ## Attributes

    * `icon_url` - URL to the icon image
    * `width` - Icon width in pixels (default: 32)
    * `height` - Icon height in pixels (default: 32)

  """
  attr :icon_url, :string, required: true
  attr :width, :string, default: "32"
  attr :height, :string, default: "32"

  def leaflet_icon(assigns) do
    ~H"""
    <leaflet-icon 
      icon-url={@icon_url} 
      width={@width} 
      height={@height}
    />
    """
  end

  @doc """
  Renders markers for a list of queries using the Web Component approach
  """
  def render_query_markers(assigns) do
    ~H"""
    <%= for query <- @queries do %>
      <.leaflet_marker 
        lat={to_string(query.lat)} 
        lng={to_string(query.lng)}
        name={query.name}
        type="query"
        tint={query.tint}
        id={"query-#{query.id}"}
        phx-click="query_marker_clicked"
        phx-value-id={query.id} />
    <% end %>
    """
  end

  @doc """
  Renders markers for a list of vehicles using the Web Component approach
  """
  def render_vehicle_markers(assigns) do
    ~H"""
    <%= for vehicle <- @vehicles do %>
      <.leaflet_marker 
        lat={to_string(vehicle.lat)} 
        lng={to_string(vehicle.lng)}
        name={"Vehicle #{vehicle.vehicle_id}"}
        type="vehicle"
        tint="orange"
        id={"vehicle-#{vehicle.vehicle_id}"}
        vehicle_id={vehicle.vehicle_id}
        route_id={vehicle.route_id || ""}
        phx-click="vehicle_marker_clicked"
        phx-value-id={vehicle.vehicle_id}>
        <.leaflet_icon 
          icon_url="/images/vehicle-icon.png" 
          width="32" 
          height="32" />
      </.leaflet_marker>
    <% end %>
    """
  end

  @doc """
  Renders markers for a list of stations using the Web Component approach
  """
  def render_station_markers(assigns) do
    ~H"""
    <%= for station <- @stations do %>
      <.leaflet_marker 
        lat={to_string(station.lat)} 
        lng={to_string(station.lng)}
        name={station.name || "Station"}
        type="station"
        tint={station.tint || "indigo"}
        id={"station-#{station.station_id}"}
        phx-click="station_marker_clicked"
        phx-value-id={station.station_id} />
    <% end %>
    """
  end

  @doc """
  Renders markers for a list of free bikes using the Web Component approach
  """
  def render_free_bike_markers(assigns) do
    ~H"""
    <%= for bike <- @free_bikes do %>
      <.leaflet_marker 
        lat={to_string(bike.lat)} 
        lng={to_string(bike.lng)}
        name={"Bike #{bike.bike_id}"}
        type="free-bike"
        tint="green"
        id={"bike-#{bike.bike_id}"}
        phx-click="bike_marker_clicked"
        phx-value-id={bike.bike_id} />
    <% end %>
    """
  end
end
