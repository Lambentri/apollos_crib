defmodule RoomSanctumWeb.LivePreview do
  use Phoenix.Component
  import Phoenix.HTML
import Phoenix.HTML.Form
use PhoenixHTMLHelpers
  import Phoenix.LiveView.Helpers

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
      _otherwise ->  "fa-train-tram"
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
      :first_quarter -> "🌗"
      :waxing_gibbous -> "🌘"
      :full_moon -> "🌑"
      :waning_gibbous -> "🌒"
      :third_quarter -> "🌓"
      :waning_crescent -> "🌔"
    end
  end

  defp to_l(direction) do
    idx = (direction / 22.5) |> Kernel.round()

    case idx do
      0 -> "N"
      1 -> "NNE"
      2 -> "NE"
      3 -> "ENE"
      4 -> "E"
      5 -> "ESE"
      6 -> "SE"
      7 -> "SSE"
      8 -> "S"
      9 -> "SSW"
      10 -> "SW"
      11 -> "WSW"
      12 -> "W"
      13 -> "WNW"
      14 -> "NW"
      15 -> "NNW"
      16 -> "N"
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
        <%= if Map.get(e, :times_live, []) != [] do %>
          <%= for t <- (e.times_live |> Enum.filter(fn t -> !is_nil(t) end )) do %>
            <p><i class="fa-solid fa-tower-broadcast fa-fw"></i> <%= t %></p>
          <% end %>
        <% else %>
          <%= for t <- e.times |> Enum.take(3) do %>
          <p><i class="fa-solid fa-clock fa-fw"></i> <%= t %></p>
          <% end %>
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
        <p>
          <i class="fa-solid fa-bicycle fa-fw"></i> <%= e.avail_std %>
          <i class="fa-solid fa-bolt-lightning"></i>
          <i class="fa-solid fa-bicycle"></i>
          <%= e.avail_elec %>
          <i class="fa-solid fa-square-parking fa-fw"></i> <%= e.capacity %>
        </p>
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
        <%= if e |> Map.get(:second_l) do %>
          <p><i class="fa-solid fa-2"></i> <i class="fa-solid fa-arrows-down-to-line"></i>: @ <%= e.second_l %></p>
        <% end %>
        <%= if e |> Map.get(:second_h) do %>
          <p><i class="fa-solid fa-2"></i> <i class="fa-solid fa-arrows-up-to-line"></i>: @ <%= e.second_h %></p>
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
      <p><i class="fa-solid fa-fw fa-wind "></i> <%= e.wind.speed %> <%= e.wind.deg |> to_l %></p>
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

  def p_cronos(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
    <div class="card-body textd-left">
    <h2 class="card-title">
      <p><i class="fa-solid fa-fw fa-clock"></i> <%= e.name %> </p>
    </h2>
    <p><%= case e.value do %>
      <% true -> %> <i class="fa-solid fa-fw fa-check fa-4x"> </i>
    <% false -> %> <i class="fa-solid fa-fw fa-remove fa-4x"> </i>
    <% end %>
    </p>
    </div>
    </div>
    <% end %>
    """
  end

  def p_gitlab(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
    <div class="card-body textd-left">
    <h2 class="card-title">
      <p><i class="fa-solid fa-fw fa-clock"></i> <%= e["commit"]["message"] %> </p>
    </h2>
    <p><%= e["duration"] %> Seconds Elapsed
    </p>
    </div>
    </div>
    <% end %>
    """
  end

  def p_packages(assigns) do
    ~H"""
    <%= for x <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
      <div class="card-body textd-left">
        <h2 class="card-title">
          <p><i class="fa-solid fa-fw fa-box"></i></p>
        </h2>
        <p>
          <i class={package_icon(x.type)}></i> <%= x.number %>
        </p>
        <ul>
          <%= for ee <- x.entries |> Enum.reverse do %>
            <li>
              <i class="fa-solid fa-clock"></i>
              <%= get_timestamp(ee) %>
              <%= ee |> Map.get("activityStatus", %{}) |> Map.get("description") %>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    <% end %>
    """
  end

  def get_timestamp(trackingentity) do
    date = trackingentity |> Map.get("localActivityDate") |> String.slice(4,4)
    time = trackingentity |> Map.get("localActivityTime")
    date <> time
  end

  def is_uri(path) do
    res = URI.parse(path)
    case {res.host, res.scheme} do
      {nil, nil} -> false
      {val, val2} -> true
    end
  end

  def do_fmt(str) do
    MDEx.to_html(str)
  end

  def p_const(assigns) do
    ~H"""
    <div class="text-xl text-accent">
      <%= case is_uri(@entries.data.body) do %>
        <%= true -> %> <img src={@entries.data.body} class="rounded-sm" />
        <%= false -> %> <%= raw do_fmt(@entries.data.body) %>
      <% end %>
    </div>
      """
  end

  defp package_icon(carrier) do
    case carrier do
      :ups -> "fa-brands fa-ups fa-fw"
      :fedex -> "fa-brands fa-fedex fa-fw"
      :usps -> "fa-brands fa-usps fa-fw"
      _otherwise -> "fa-solid fa-box fa-fw"
    end
  end
end
