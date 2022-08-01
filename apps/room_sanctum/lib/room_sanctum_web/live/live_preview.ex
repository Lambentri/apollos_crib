defmodule RoomSanctumWeb.LivePreview do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers

  alias Phoenix.LiveView.JS

  defp gtfs_icon(route_str) do
    case route_str do
      "LightRail" -> "fa-train-tram"
      "Subway" -> "fa-train-subway"
      "Rail" -> "fa-train"
      "Bus" -> "fa-bus"
      "Ferry" -> "fa-ferry"
      "CableCar" -> "fa-cable-car"
      "Funicular" -> "fa-mountain"
      "Trolleybus" -> "fa-bus-simple"
      "Monorail" -> "fa-magic"
    end
  end

  defp weather_icon(status) do
    case status do
      "Clouds" -> "fa-cloud"
      _ -> "!!!"
    end
  end

  defp moon_icon(phase) do
    case phase do
      :new_moon -> "🌕"
      :waxing_crescent -> "🌖"
      :first_quarter ->"🌗"
      :waxing_gibbous -> "🌘"
      :full_moon -> "🌑"
      :waning_gibbous -> "🌒"
      :last_quarter -> "🌓"
      :waning_crescent -> "🌔"
    end
  end

  def p_gtfs(assigns) do
    ~H"""
      <%= for e <- @entries.data do %>
        <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
          <div class="card-body text-left">
          <h2 class="card-title">
            <p><i class={"fa-solid fa-fw #{gtfs_icon(e.mode)}"}></i> <%= e.route %> to <%= e.dest %></p>
          </h2>
          <%= for t <- e.times |> Enum.take(3) do %>
            <p><i class="fa-solid fa-clock fa-fw"></i> <%= t %></p>
          <% end %>
          </div>
        </div>
      <% end %>
      """
  end

  def p_gbfs(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
        <div class="card-body text-left">
        <h2 class="card-title">
          <p><i class="fa-solid fa-fw fa-bicycle"></i> <%= e.name %> </p>
        </h2>
        <p><i class="fa-solid fa-bicycle fa-fw"></i> <%= e.avail %> <i class="fa-solid fa-square-parking fa-fw"></i> <%= e.capacity %></p>
        </div>
      </div>
    <% end %>
    """
  end

  def p_tidal(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
        <div class="card-body text-left">
        <p><i class="fa-solid fa-1"></i> <i class="fa-solid fa-arrows-down-to-line"></i>: @ <%= e.first_l %></p>
        <p><i class="fa-solid fa-1"></i> <i class="fa-solid fa-arrows-up-to-line"></i>: @ <%= e.first_h %></p>
        <p><i class="fa-solid fa-2"></i> <i class="fa-solid fa-arrows-down-to-line"></i>: @ <%= e.second_l %></p>
        <%= if e |> Map.get :second_h do %>
          <p><i class="fa-solid fa-2"></i> <i class="fa-solid fa-arrows-up-to-line"></i>: @ <%= e.first_l %></p>
        <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def p_weather(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
      <div class="card-body textd-left">
      <h2 class="card-title">
        <p><i class="fa-solid fa-fw fa-cloud-sun"></i> <%= e.name %> </p>
      </h2>
      <p><i class={"fa-solid fa-fw #{weather_icon(e.weather)}"}></i> <%= e.weather %></p>
      <p><i class="fa-solid fa-fw fa-temperature-half"></i> <%= e.temp %>&deg;</p>
      <p><i class="fa-solid fa-fw fa-droplet "></i> <%= e.hum %> &percnt; </p>
      <p><i class="fa-solid fa-fw fa-gem "></i> <%= e.pressure %> mPa?</p>
      </div>
    </div>
    <% end %>
      """
  end

  def p_aqi(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
        <div class="card-body text-left">
        <h2 class="card-title">
          <p><i class="fa-solid fa-fw fa-lungs"></i> <%= e.name %> </p>
        </h2>
          <%= if e |> Map.get(:pm25) do %>
            <p> PM2.5: <%= e.pm25 %> </p>
          <% end %>
          <%= if e |> Map.get(:pm10) do %>
            <p> PM10: <%= e.pm10 %> </p>
          <% end %>
          <%= if e |> Map.get(:no2) do %>
            <p> NO2: <%= e.no2 %> </p>
          <% end %>
          <%= if e |> Map.get(:ozone) do %>
            <p> O3: <%= e.ozone %> </p>
          <% end %>
          <%= if e |> Map.get(:so2) do %>
            <p> SO2: <%= e.so2 %> </p>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def p_ephem(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
    <div class="card-body textd-left">
    <h2 class="card-title">
      <p><i class="fa-solid fa-fw fa-cloud-sun"></i> <%= e.name %> </p>
    </h2>
    <p><%= moon_icon(e.phase) %> &emsp; <%= e.phase %></p>
    <p><i class="fa-solid fa-fw fa-sun"></i><i class="fa-solid fa-arrows-up-to-line"></i> <%= e.sunrise %></p>
    <p><i class="fa-solid fa-fw fa-sun"></i><i class="fa-solid fa-arrows-down-to-line"></i> <%= e.sunset %></p>
    </div>
    </div>
    <% end %>
    """
  end

  def p_calendar(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
    <div class="card-body textd-left">
    <h2 class="card-title">
      <p><i class="fa-solid fa-fw fa-cloud-sun"></i> <%= e.description %> </p>
    </h2>
    <p><i class="fa-solid fa-fw fa-calendar-day"></i> <%= e.date_start %></p>
    </div>
    </div>
    <% end %>
    """
  end
end
