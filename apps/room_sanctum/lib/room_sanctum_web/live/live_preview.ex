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

  def tsl(%Time{} = t), do: tsl(t |> Time.to_string)
  def tsl(st), do: st |> String.slice(0,5)

  def tsls(%Time{} = t), do: tsl(t |> Time.to_string)
  def tsls(st), do: st |> String.slice(0,8)

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

  def i_gtfs(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
        <div class="flex items-center my-1">
          <div class="w-1/4 lg:w-1/12">
            <i class={"fa-solid fa-3x fa-fw #{gtfs_icon(e.mode)}"}></i>
          </div>
          <div class="w-3/4 lg:w-11/12">
            <div class="flex justify-between">
              <div>
                <span class="font-bold text-lg lg:text-4xl text-accent">
                  <%= e.route %>
                </span>
                <span class="uppercase text-secondary lg:text-2xl lg:font-bold"> <%= if e.dir do %> (<%= e.dir %>) <% end %> </span> <br />
                <span class="lg:text-2xl"><%= e.dest %></span>
              </div>
              <div class="lg:flex lg:gap-8">
                <%= if Map.get(e, :times_live, []) != [] do %>
                  <%= for t <- (e.times_live |> Enum.filter(fn t -> !is_nil(t) end ) |> Enum.take(2) ) do %>
                    <p class="lg:text-4xl"><i class="fa-solid fa-tower-broadcast fa-fw"></i><span class="text-accent"> <%= tsl(t) %></span></p>
                  <% end %>
                <% else %>
                  <%= for t <- e.times |> Enum.take(2) do %>
                  <p  class="lg:text-4xl"><i class="fa-solid fa-clock fa-fw"></i> <span class="text-accent"><%= tsl(t) %></span></p>
                  <% end %>
                <% end %>
              </div>
            </div>
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

  def i_gbfs(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
        <div class="flex items-center">
          <div class="w-1/4 lg:w-1/12 py-2">
            <i class={"fa-solid fa-3x fa-fw fa-bicycle"}></i>
          </div>
          <div class="w-3/4 lg:w-11/12">
            <div class="flex justify-between">
              <div>
                <span class="font-bold text-lg lg:text-4xl text-accent">
                  <%= e.name |> String.split(" ") |> Enum.take(3) |> Enum.join(" ") %>
                </span>
              </div>
              <div class="lg:flex lg:gap-8">
                <p class="lg:text-4xl"><i class="fa-solid fa-bicycle fa-fw"></i> <span class="text-accent"><%= e.avail_std %></span></p>
                <p class="lg:text-4xl"><i class="fa-solid fa-bolt-lightning fa-fw"></i> <span class="text-accent"><%= e.avail_elec %></span></p>
                <p class="lg:text-4xl"><i class="fa-solid fa-square-parking fa-fw"></i> <span class="text-accent"><%= e.docks_avail %>/<%= e.capacity %></span></p>
              </div>
            </div>
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

  def i_tidal(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
        <div class="flex items-center">
          <div class="w-1/4 lg:w-1/12 py-2">
            <i class={"fa-solid fa-3x fa-fw fa-water"}></i>
          </div>
          <div class="w-3/4 lg:w-11/12 mr-4  ">
            <div class="flex justify-between">
              <div class="font-bold lg:text-4xl">
                <p><i class="fa-solid fa-1"></i><sup>st</sup> <i class="fa-solid fa-arrows-down-to-line"></i><span class="text-accent"> @<%= e.first_l %></span></p>
                <p><i class="fa-solid fa-1"></i><sup>st</sup> <i class="fa-solid fa-arrows-up-to-line"></i><span class="text-accent"> @<%= e.first_h %></span></p>
              </div>
              <div class="lg:text-4xl">
                <%= if e |> Map.get(:second_l) do %>
                  <p><i class="fa-solid fa-2"></i><sup>nd</sup> <i class="fa-solid fa-arrows-down-to-line"></i><span class="text-accent"> @<%= e.second_l %></span></p>
                <% end %>
                <%= if e |> Map.get(:second_h) do %>
                  <p><i class="fa-solid fa-2"></i><sup>nd</sup> <i class="fa-solid fa-arrows-up-to-line"></i><span class="text-accent"> @<%= e.second_h %></span></p>
                <% end %>
              </div>
            </div>
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

  def i_weather(assigns) do
    ~H"""
        <%= for e <- @entries.data do %>
        <div class="flex items-center">
          <div class="w-1/4 lg:w-1/12 py-2">
            <i class={"fa-solid fa-3x fa-fw fa-cloud-sun"}></i>
          </div>
          <div class="w-3/4 lg:w-11/12 mr-4">
            <div class="flex flex-col lg:flex-row justify-between">
              <div class="text-lg text-accent lg:text-4xl lg:font-bold"><%= e.name %></div>
              <div class="flex items-center justify-between lg:text-4xl lg:gap-8 lg:justify-normal">
                <div><span class="text-accent"><%= e.feel %></span>&deg;</div>
                <div class="flex flex-col"><div><span class="text-accent"><%= e.wind.speed %></span><sub>MPH</sub> <%= e.wind.deg |> to_l %></div> </div>
                <div class="flex flex-col"><div><span class="text-accent"><%= e.hum %></span>%</div></div>
                <div class="flex flex-col"><div><span class="text-accent"><%= e.weather %></span></div></div>
              </div>
            </div>
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

  def i_aqi(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="flex items-center">
        <div class="w-1/4 lg:w-1/12">
          <i class={"fa-solid fa-3x fa-fw fa-lungs"}></i>
        </div>
        <div class="w-3/4 lg:w-11/12">
          <div class="flex justify-between">
            <div>
              <span class="font-bold text-lg text-accent lg:text-4xl">
                <%= e.name %>
              </span>
            </div>
            <div class="lg:text-4xl lg:gap-8">
              <%= if e |> Map.get(:pm25) do %>
                <p> PM<sup>2.5</sup>: <span class="text-accent"><%= e.pm25 %></span> </p>
              <% end %>
              <%= if e |> Map.get(:pm10) do %>
                <p> PM<sup>10</sup>: <span class="text-accent"><%= e.pm10 %></span> </p>
              <% end %>
              <%= if e |> Map.get(:no2) do %>
                <p> NO<sub>2</sub>: <span class="text-accent"><%= e.no2 %></span> </p>
              <% end %>
              <%= if e |> Map.get(:ozone) do %>
                <p> O<sub>3</sub>: <span class="text-accent"><%= e.ozone %></span> </p>
              <% end %>
              <%= if e |> Map.get(:so2) do %>
                <p> SO<sub>2</sub>: <span class="text-accent"><%= e.so2 %></span> </p>
              <% end %>
            </div>
          </div>
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
      <p><i class="fa-solid fa-fw fa-cloud-sun"></i> <%= e |> Map.get(:name) %> </p>
    </h2>
    <p><%= moon_icon(e |> Map.get(:phase, :new_moon)) %> &emsp; <%= e |> Map.get(:phase, :new_moon) %></p>
    <p><i class="fa-solid fa-fw fa-sun"></i><i class="fa-solid fa-arrows-up-to-line"></i> <%= e |> Map.get(:sunrise) %></p>
    <p><i class="fa-solid fa-fw fa-sun"></i><i class="fa-solid fa-arrows-down-to-line"></i> <%= e |> Map.get(:sunset) %></p>
    </div>
    </div>
    <% end %>
    """
  end

  def i_ephem(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="flex items-center">
        <div class="w-1/4 lg:w-1/12">
          <i class={"fa-solid fa-3x fa-fw fa-sun"}></i>
        </div>
        <div class="w-3/4 lg:w-11/12 mr-4">
            <div class="flex flex-col lg:flex-row justify-between">
              <div class="flex items-center justify-between lg:text-4xl lg:font-bold lg:gap-2">
                <div class="text-lg text-accent lg:text-4xl"><%= e.name %></div>
                <div><%= moon_icon(e.phase) %> </div>
              </div>
              <div class="flex items-center justify-between lg:text-4xl lg:gap-8">
                <p><i class="fa-solid fa-fw fa-sun"></i><i class="fa-solid fa-arrows-up-to-line"></i> <span class="text-accent"><%= e.sunrise |> tsls %></span></p>
                <p><i class="fa-solid fa-fw fa-sun"></i><i class="fa-solid fa-arrows-down-to-line"></i> <span class="text-accent"><%= e.sunset |> tsls %></span></p>
              </div>
            </div>
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

  def i_calendar(assigns) do
    ~H"""
      <%= for e <- @entries.data do %>
      <div class="flex items-center">
        <div class="w-1/4 lg:w-1/12">
          <i class={"fa-solid fa-3x fa-fw fa-calendar"}></i>
        </div>
        <div class="w-3/4 lg:w-11/12 mr-4">
            <div class="flex flex-col lg:flex-row justify-between">
              <div class="flex items-center justify-between lg:text-4xl lg:font-bold lg:gap-2">
                <div class="text-lg text-accent lg:text-4xl"><%= e.description %></div>
              </div>
              <div class="flex items-center justify-between lg:text-4xl lg:gap-8">
                <p><i class="fa-solid fa-fw fa-calendar"></i><span class="text-accent"><%= e.date_start  %></span></p>
              </div>
            </div>
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

  def i_cronos(assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="flex items-center">
        <div class="w-1/4 lg:w-1/12">
          <i class={"fa-solid fa-3x fa-fw fa-clock"}></i>
        </div>
        <div class="w-3/4 lg:w-11/12 mr-4">
            <div class="flex flex-col lg:flex-row justify-between">
              <div class="flex items-center justify-between lg:text-4xl lg:font-bold lg:gap-2">
                <div class="text-lg text-accent lg:text-4xl"><%= e.name %></div>
              </div>
              <div class="flex items-center justify-between lg:text-4xl lg:gap-8">
                <p>
                <%= case e.value do %>
                    <% true -> %> <i class="fa-solid fa-fw fa-check fa-2x"> </i>
                  <% false -> %> <i class="fa-solid fa-fw fa-remove fa-2x"> </i>
                  <% end %>
                </p>
              </div>
            </div>
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
