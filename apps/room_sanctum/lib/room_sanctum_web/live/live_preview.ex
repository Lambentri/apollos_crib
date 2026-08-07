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

  # Countdown entries carry a :mode key; the original modulo entries only have
  # :name and :value, so the two shapes are told apart by that.
  def p_cronos(%{entries: %{data: [%{mode: :countdown} | _]}} = assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
        <div class="card-body text-left">
          <h2 class="card-title">
            <p>
              <i class={"fa-solid fa-fw #{if e.direction == :until, do: "fa-hourglass-half", else: "fa-hourglass-end"}"}></i>
              <%= e.name %>
            </p>
          </h2>
          <div class="flex items-end gap-3">
            <span class="text-5xl font-mono font-bold"><%= e.days %></span>
            <span class="text-lg pb-1"><%= if e.days == 1, do: "day", else: "days" %></span>
            <span class="text-2xl font-mono pb-1 opacity-80">
              <%= cronos_pad(e.hours) %>:<%= cronos_pad(e.minutes) %>
            </span>
          </div>
          <p class="text-sm opacity-90">
            <%= if e.direction == :until, do: "until", else: "since" %>
            <%= cronos_date(e.target) %><%= if e.rolled, do: " (next occurrence)" %>
          </p>
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

  def i_cronos(%{entries: %{data: [%{mode: :countdown} | _]}} = assigns) do
    ~H"""
    <%= for e <- @entries.data do %>
      <div class="flex items-center">
        <div class="w-1/4 lg:w-1/12">
          <i class={"fa-solid fa-3x fa-fw #{if e.direction == :until, do: "fa-hourglass-half", else: "fa-hourglass-end"}"}></i>
        </div>
        <div class="w-3/4 lg:w-11/12 mr-4">
          <div class="flex flex-col lg:flex-row justify-between">
            <div class="text-lg text-accent lg:text-4xl lg:font-bold"><%= e.name %></div>
            <div class="flex items-baseline gap-2 lg:text-4xl">
              <span class="font-mono font-bold text-accent"><%= e.days %></span>
              <span class="text-sm lg:text-2xl"><%= if e.days == 1, do: "day", else: "days" %></span>
              <span class="font-mono text-sm lg:text-2xl opacity-80">
                <%= cronos_pad(e.hours) %>:<%= cronos_pad(e.minutes) %>
              </span>
            </div>
          </div>
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
    <div class="flex flex-col gap-2">
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
      <div class="card-body">
        <div class="flex items-start justify-between gap-2">
          <div class="flex items-center gap-2 min-w-0">
            <span class={"badge #{gitlab_status_class(e["status"])} gap-1"}>
              <i class={"fa-solid fa-fw #{gitlab_status_icon(e["status"])}"}></i>
              <%= e["status"] %>
            </span>
            <span class="font-bold truncate"><%= e["name"] %></span>
            <%= if e["stage"] do %>
              <span class="badge badge-ghost"><%= e["stage"] %></span>
            <% end %>
            <%= if e["allow_failure"] do %>
              <span class="badge badge-warning badge-xs">allow-fail</span>
            <% end %>
          </div>
          <%= if e["web_url"] do %>
            <a href={e["web_url"]} target="_blank" rel="noopener" class="link link-hover text-xs whitespace-nowrap">
              <i class="fa-solid fa-arrow-up-right-from-square"></i> open
            </a>
          <% end %>
        </div>

        <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs opacity-90">
          <%= if e["ref"] do %>
            <span><i class="fa-solid fa-fw fa-code-branch"></i> <%= e["ref"] %></span>
          <% end %>
          <%= if get_in(e, ["commit", "short_id"]) do %>
            <span>
              <i class="fa-solid fa-fw fa-code-commit"></i>
              <code><%= get_in(e, ["commit", "short_id"]) %></code>
              <%= get_in(e, ["commit", "title"]) || get_in(e, ["commit", "message"]) %>
            </span>
          <% end %>
          <%= if get_in(e, ["commit", "author_name"]) do %>
            <span><i class="fa-solid fa-fw fa-user"></i> <%= get_in(e, ["commit", "author_name"]) %></span>
          <% end %>
          <span><i class="fa-solid fa-fw fa-stopwatch"></i> <%= gitlab_format_duration(e["duration"]) %></span>
          <%= if e["coverage"] do %>
            <span><i class="fa-solid fa-fw fa-percent"></i> <%= e["coverage"] %>%</span>
          <% end %>
          <%= if e["started_at"] do %>
            <span><i class="fa-solid fa-fw fa-clock"></i> <%= gitlab_format_time(e["started_at"]) %></span>
          <% end %>
          <%= if e["failure_reason"] do %>
            <span class="text-warning"><i class="fa-solid fa-fw fa-triangle-exclamation"></i> <%= e["failure_reason"] %></span>
          <% end %>
        </div>
      </div>
    </div>
    <% end %>
    </div>
    """
  end

  defp gitlab_status_class("success"), do: "badge-success"
  defp gitlab_status_class("failed"), do: "badge-error"
  defp gitlab_status_class("running"), do: "badge-info"
  defp gitlab_status_class("canceled"), do: "badge-ghost"
  defp gitlab_status_class("skipped"), do: "badge-ghost"
  defp gitlab_status_class("manual"), do: "badge-ghost"
  defp gitlab_status_class(_), do: "badge-warning"

  defp gitlab_status_icon("success"), do: "fa-check"
  defp gitlab_status_icon("failed"), do: "fa-xmark"
  defp gitlab_status_icon("running"), do: "fa-spinner fa-spin"
  defp gitlab_status_icon("pending"), do: "fa-hourglass-half"
  defp gitlab_status_icon("created"), do: "fa-circle-dot"
  defp gitlab_status_icon("waiting_for_resource"), do: "fa-pause"
  defp gitlab_status_icon("canceled"), do: "fa-ban"
  defp gitlab_status_icon("skipped"), do: "fa-forward"
  defp gitlab_status_icon("manual"), do: "fa-hand-pointer"
  defp gitlab_status_icon(_), do: "fa-circle-question"

  defp gitlab_format_duration(nil), do: "—"
  defp gitlab_format_duration(secs) when is_number(secs) do
    total = round(secs)
    cond do
      total < 60 -> "#{total}s"
      total < 3600 -> "#{div(total, 60)}m #{rem(total, 60)}s"
      true -> "#{div(total, 3600)}h #{div(rem(total, 3600), 60)}m"
    end
  end
  defp gitlab_format_duration(_), do: "—"

  defp gitlab_format_time(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} ->
        secs = DateTime.diff(DateTime.utc_now(), dt)
        cond do
          secs < 60 -> "#{secs}s ago"
          secs < 3600 -> "#{div(secs, 60)}m ago"
          secs < 86_400 -> "#{div(secs, 3600)}h ago"
          true -> "#{div(secs, 86_400)}d ago"
        end

      _ -> iso
    end
  end
  defp gitlab_format_time(_), do: "—"

  def p_github(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
    <%= for e <- @entries.data do %>
    <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
      <div class="card-body">
        <div class="flex items-start justify-between gap-2">
          <div class="flex items-center gap-2 min-w-0">
            <span class={"badge #{github_status_class(e["status"], e["conclusion"])} gap-1"}>
              <i class={"fa-solid fa-fw #{github_status_icon(e["status"], e["conclusion"])}"}></i>
              <%= github_status_label(e["status"], e["conclusion"]) %>
            </span>
            <span class="font-bold truncate">
              <%= e["display_title"] || e["name"] %>
            </span>
            <%= if e["name"] && e["display_title"] && e["name"] != e["display_title"] do %>
              <span class="badge badge-ghost"><%= e["name"] %></span>
            <% end %>
            <%= if e["event"] do %>
              <span class="badge badge-ghost badge-sm"><%= e["event"] %></span>
            <% end %>
            <%= if e["run_attempt"] && e["run_attempt"] > 1 do %>
              <span class="badge badge-warning badge-xs">retry #<%= e["run_attempt"] %></span>
            <% end %>
          </div>
          <%= if e["html_url"] do %>
            <a href={e["html_url"]} target="_blank" rel="noopener" class="link link-hover text-xs whitespace-nowrap">
              <i class="fa-solid fa-arrow-up-right-from-square"></i> open
            </a>
          <% end %>
        </div>

        <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs opacity-90">
          <%= if get_in(e, ["repository", "full_name"]) do %>
            <span><i class="fa-brands fa-fw fa-github"></i> <%= get_in(e, ["repository", "full_name"]) %></span>
          <% end %>
          <%= if e["head_branch"] do %>
            <span><i class="fa-solid fa-fw fa-code-branch"></i> <%= e["head_branch"] %></span>
          <% end %>
          <%= if e["head_sha"] do %>
            <span>
              <i class="fa-solid fa-fw fa-code-commit"></i>
              <code><%= String.slice(e["head_sha"], 0, 7) %></code>
              <%= get_in(e, ["head_commit", "message"]) |> github_first_line() %>
            </span>
          <% end %>
          <%= if get_in(e, ["head_commit", "author", "name"]) || get_in(e, ["actor", "login"]) do %>
            <span><i class="fa-solid fa-fw fa-user"></i>
              <%= get_in(e, ["head_commit", "author", "name"]) || get_in(e, ["actor", "login"]) %>
            </span>
          <% end %>
          <span><i class="fa-solid fa-fw fa-stopwatch"></i> <%= github_duration(e) %></span>
          <%= if e["run_started_at"] || e["started_at"] || e["created_at"] do %>
            <span><i class="fa-solid fa-fw fa-clock"></i>
              <%= gitlab_format_time(e["run_started_at"] || e["started_at"] || e["created_at"]) %>
            </span>
          <% end %>
        </div>
      </div>
    </div>
    <% end %>
    </div>
    """
  end

  defp github_first_line(nil), do: ""
  defp github_first_line(s) when is_binary(s), do: s |> String.split("\n", parts: 2) |> List.first()
  defp github_first_line(_), do: ""

  defp github_status_class(_status, "success"), do: "badge-success"
  defp github_status_class(_status, "failure"), do: "badge-error"
  defp github_status_class(_status, "timed_out"), do: "badge-error"
  defp github_status_class(_status, "cancelled"), do: "badge-ghost"
  defp github_status_class(_status, "skipped"), do: "badge-ghost"
  defp github_status_class(_status, "neutral"), do: "badge-ghost"
  defp github_status_class(_status, "action_required"), do: "badge-warning"
  defp github_status_class("in_progress", _), do: "badge-info"
  defp github_status_class("queued", _), do: "badge-warning"
  defp github_status_class("waiting", _), do: "badge-warning"
  defp github_status_class("requested", _), do: "badge-warning"
  defp github_status_class("pending", _), do: "badge-warning"
  defp github_status_class(_, _), do: "badge-ghost"

  defp github_status_icon(_status, "success"), do: "fa-check"
  defp github_status_icon(_status, "failure"), do: "fa-xmark"
  defp github_status_icon(_status, "timed_out"), do: "fa-clock"
  defp github_status_icon(_status, "cancelled"), do: "fa-ban"
  defp github_status_icon(_status, "skipped"), do: "fa-forward"
  defp github_status_icon(_status, "neutral"), do: "fa-circle-minus"
  defp github_status_icon(_status, "action_required"), do: "fa-triangle-exclamation"
  defp github_status_icon("in_progress", _), do: "fa-spinner fa-spin"
  defp github_status_icon("queued", _), do: "fa-hourglass-half"
  defp github_status_icon("waiting", _), do: "fa-pause"
  defp github_status_icon("requested", _), do: "fa-hand-pointer"
  defp github_status_icon("pending", _), do: "fa-hourglass-half"
  defp github_status_icon(_, _), do: "fa-circle-question"

  defp github_status_label(status, nil), do: status || "?"
  defp github_status_label("completed", conclusion) when is_binary(conclusion), do: conclusion
  defp github_status_label(status, _), do: status || "?"

  defp github_duration(%{"started_at" => start, "completed_at" => done})
       when is_binary(start) and is_binary(done) do
    with {:ok, s, _} <- DateTime.from_iso8601(start),
         {:ok, e, _} <- DateTime.from_iso8601(done) do
      gitlab_format_duration(DateTime.diff(e, s))
    else
      _ -> "—"
    end
  end

  defp github_duration(%{"run_started_at" => start, "updated_at" => done})
       when is_binary(start) and is_binary(done) do
    with {:ok, s, _} <- DateTime.from_iso8601(start),
         {:ok, e, _} <- DateTime.from_iso8601(done) do
      gitlab_format_duration(DateTime.diff(e, s))
    else
      _ -> "—"
    end
  end

  defp github_duration(%{"run_started_at" => start}) when is_binary(start) do
    case DateTime.from_iso8601(start) do
      {:ok, s, _} -> gitlab_format_duration(DateTime.diff(DateTime.utc_now(), s))
      _ -> "—"
    end
  end

  defp github_duration(_), do: "—"

  def p_drought(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
    <%= for e <- @entries.data do %>
      <%= cond do %>
      <% e["status"] == "not_yet_implemented" -> %>
        <div class="card card-compact w-full bg-base-200 shadow">
          <div class="card-body">
            <p class="text-sm">
              <i class="fa-solid fa-fw fa-hourglass-half"></i>
              Product <span class="font-bold"><%= e["product"] %></span> is reserved but not yet implemented.
            </p>
          </div>
        </div>
      <% true -> %>
        <% top = drought_top_category(e) %>
        <div class={"card card-compact w-full shadow-xl #{drought_card_class(top)}"}>
          <div class="card-body">
            <div class="flex items-start justify-between gap-2">
              <div class="flex items-center gap-2 min-w-0">
                <span class={"badge gap-1 #{drought_badge_class(top)}"}>
                  <i class="fa-solid fa-fw fa-sun-plant-wilt"></i>
                  <%= drought_top_label(top) %>
                </span>
                <span class="font-bold truncate">
                  <%= e["county"] || e["state"] %>
                </span>
                <%= if e["state"] && e["county"] do %>
                  <span class="badge badge-ghost badge-sm"><%= e["state"] %></span>
                <% end %>
                <%= if e["fips"] do %>
                  <span class="badge badge-ghost badge-xs">FIPS <%= e["fips"] %></span>
                <% end %>
              </div>
              <span class="text-xs opacity-90"><%= drought_format_date(e["mapDate"]) %></span>
            </div>
            <div class="grid grid-cols-6 gap-1 mt-2 text-xs">
              <%= for {label, key, color} <- drought_categories() do %>
                <div class={"px-1 py-0.5 rounded text-center #{color}"} title={label}>
                  <div class="font-mono font-bold"><%= drought_pct(e[key]) %>%</div>
                  <div class="opacity-75"><%= drought_short(key) %></div>
                </div>
              <% end %>
            </div>
            <%= if e["validStart"] && e["validEnd"] do %>
              <p class="text-xs opacity-70 mt-1">
                Valid <%= drought_format_date(e["validStart"]) %> &mdash; <%= drought_format_date(e["validEnd"]) %>
              </p>
            <% end %>
          </div>
        </div>
      <% end %>
    <% end %>
    </div>
    """
  end

  defp drought_categories do
    [
      {"None", "none", "bg-emerald-500/30"},
      {"D0 — Abnormally Dry", "d0", "bg-yellow-300/40"},
      {"D1 — Moderate Drought", "d1", "bg-amber-400/40"},
      {"D2 — Severe Drought", "d2", "bg-orange-500/50"},
      {"D3 — Extreme Drought", "d3", "bg-red-500/50"},
      {"D4 — Exceptional Drought", "d4", "bg-red-800/60 text-white"}
    ]
  end

  defp drought_short("none"), do: "none"
  defp drought_short("d0"), do: "D0"
  defp drought_short("d1"), do: "D1"
  defp drought_short("d2"), do: "D2"
  defp drought_short("d3"), do: "D3"
  defp drought_short("d4"), do: "D4"
  defp drought_short(other), do: to_string(other)

  defp drought_pct(nil), do: "—"
  defp drought_pct(v) when is_number(v), do: :erlang.float_to_binary(v * 1.0, decimals: 0)
  defp drought_pct(v) when is_binary(v), do: v
  defp drought_pct(_), do: "—"

  # Returns the worst category with a non-zero percentage.
  defp drought_top_category(e) do
    cond do
      drought_nonzero?(e["d4"]) -> :d4
      drought_nonzero?(e["d3"]) -> :d3
      drought_nonzero?(e["d2"]) -> :d2
      drought_nonzero?(e["d1"]) -> :d1
      drought_nonzero?(e["d0"]) -> :d0
      true -> :none
    end
  end

  defp drought_nonzero?(v) when is_number(v) and v > 0, do: true
  defp drought_nonzero?(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} when f > 0 -> true
      _ -> false
    end
  end
  defp drought_nonzero?(_), do: false

  defp drought_top_label(:none), do: "no drought"
  defp drought_top_label(:d0), do: "D0 abnormally dry"
  defp drought_top_label(:d1), do: "D1 moderate"
  defp drought_top_label(:d2), do: "D2 severe"
  defp drought_top_label(:d3), do: "D3 extreme"
  defp drought_top_label(:d4), do: "D4 exceptional"

  defp drought_badge_class(:none), do: "badge-success"
  defp drought_badge_class(:d0), do: "badge-warning"
  defp drought_badge_class(:d1), do: "badge-warning"
  defp drought_badge_class(:d2), do: "badge-error"
  defp drought_badge_class(:d3), do: "badge-error"
  defp drought_badge_class(:d4), do: "badge-error"

  defp drought_card_class(:none), do: "bg-success text-success-content"
  defp drought_card_class(:d0), do: "bg-warning text-warning-content"
  defp drought_card_class(:d1), do: "bg-warning text-warning-content"
  defp drought_card_class(:d2), do: "bg-error text-error-content"
  defp drought_card_class(:d3), do: "bg-error text-error-content"
  defp drought_card_class(:d4), do: "bg-error text-error-content"

  defp drought_format_date(nil), do: "—"
  defp drought_format_date(s) when is_binary(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _} -> dt |> DateTime.to_date() |> Date.to_string()
      _ ->
        case NaiveDateTime.from_iso8601(s) do
          {:ok, dt} -> dt |> NaiveDateTime.to_date() |> Date.to_string()
          _ -> s
        end
    end
  end
  defp drought_format_date(_), do: "—"

  def p_pollen(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
    <%= for day <- @entries.data do %>
      <% top = pollen_top_category(day) %>
      <div class={"card card-compact w-full shadow-xl #{pollen_card_class(top)}"}>
        <div class="card-body">
          <div class="flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <span class={"badge gap-1 #{pollen_badge_class(top)}"}>
                <i class="fa-solid fa-fw fa-seedling"></i>
                <%= pollen_top_label(top) %>
              </span>
              <span class="font-bold"><%= pollen_format_date(day["date"]) %></span>
            </div>
          </div>

          <div class="grid grid-cols-3 gap-2 mt-2 text-sm">
            <%= for type <- (day["pollenTypeInfo"] || []) do %>
              <% upi = get_in(type, ["indexInfo", "value"]) %>
              <% cat = get_in(type, ["indexInfo", "category"]) %>
              <div class={"px-2 py-1 rounded text-center #{pollen_type_class(upi)}"}>
                <div class="font-bold uppercase"><%= type["displayName"] %></div>
                <div class="text-2xl font-mono"><%= upi || "—" %></div>
                <div class="text-xs opacity-90"><%= cat || "—" %></div>
                <%= if type["inSeason"] == false do %>
                  <div class="text-xs opacity-60">off-season</div>
                <% end %>
              </div>
            <% end %>
          </div>

          <% plants = day["plantInfo"] || [] %>
          <% in_season = Enum.filter(plants, &(&1["inSeason"] == true and pollen_nonzero?(&1))) %>
          <%= if in_season != [] do %>
            <details class="text-xs mt-1">
              <summary class="cursor-pointer opacity-90">
                Active species (<%= length(in_season) %>)
              </summary>
              <div class="flex flex-wrap gap-1 mt-1">
                <%= for p <- in_season do %>
                  <% upi = get_in(p, ["indexInfo", "value"]) %>
                  <span class={"badge badge-sm #{pollen_species_class(upi)}"}>
                    <%= p["displayName"] %> (<%= upi || "?" %>)
                  </span>
                <% end %>
              </div>
            </details>
          <% end %>
        </div>
      </div>
    <% end %>
    </div>
    """
  end

  defp pollen_format_date(%{"year" => y, "month" => m, "day" => d}),
    do: "#{y}-#{pad2(m)}-#{pad2(d)}"

  defp pollen_format_date(_), do: "—"

  defp pad2(n) when is_integer(n) and n < 10, do: "0#{n}"
  defp pad2(n), do: "#{n}"

  defp pollen_nonzero?(plant) do
    case get_in(plant, ["indexInfo", "value"]) do
      n when is_number(n) and n > 0 -> true
      _ -> false
    end
  end

  defp pollen_top_category(day) do
    (day["pollenTypeInfo"] || [])
    |> Enum.map(fn t -> get_in(t, ["indexInfo", "value"]) || 0 end)
    |> Enum.max(fn -> 0 end)
  end

  defp pollen_top_label(0), do: "no pollen"
  defp pollen_top_label(1), do: "very low"
  defp pollen_top_label(2), do: "low"
  defp pollen_top_label(3), do: "moderate"
  defp pollen_top_label(4), do: "high"
  defp pollen_top_label(5), do: "very high"
  defp pollen_top_label(_), do: "?"

  defp pollen_badge_class(0), do: "badge-success"
  defp pollen_badge_class(1), do: "badge-success"
  defp pollen_badge_class(2), do: "badge-info"
  defp pollen_badge_class(3), do: "badge-warning"
  defp pollen_badge_class(4), do: "badge-error"
  defp pollen_badge_class(5), do: "badge-error"
  defp pollen_badge_class(_), do: "badge-ghost"

  defp pollen_card_class(0), do: "bg-base-100"
  defp pollen_card_class(1), do: "bg-success/20"
  defp pollen_card_class(2), do: "bg-info/20"
  defp pollen_card_class(3), do: "bg-warning/30"
  defp pollen_card_class(4), do: "bg-error/30"
  defp pollen_card_class(5), do: "bg-error/40"
  defp pollen_card_class(_), do: "bg-base-100"

  defp pollen_type_class(nil), do: "bg-base-300/40"
  defp pollen_type_class(0), do: "bg-base-300/40"
  defp pollen_type_class(1), do: "bg-success/30"
  defp pollen_type_class(2), do: "bg-info/30"
  defp pollen_type_class(3), do: "bg-warning/40"
  defp pollen_type_class(4), do: "bg-error/40"
  defp pollen_type_class(5), do: "bg-error/50"
  defp pollen_type_class(_), do: "bg-base-300/40"

  defp pollen_species_class(n) when is_number(n) and n >= 4, do: "badge-error"
  defp pollen_species_class(n) when is_number(n) and n >= 3, do: "badge-warning"
  defp pollen_species_class(n) when is_number(n) and n >= 2, do: "badge-info"
  defp pollen_species_class(_), do: "badge-success"

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

  defp cronos_pad(n) when is_integer(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
  defp cronos_pad(n), do: to_string(n)

  defp cronos_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%-d %b %Y")
  defp cronos_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%-d %b %Y")
  defp cronos_date(other), do: to_string(other)

  def p_mailbox(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <%= if @entries.data == [] do %>
        <div class="text-sm opacity-60">-no messages-</div>
      <% end %>
      <%= for e <- @entries.data do %>
        <div class={"card card-compact w-full shadow-xl #{if e.seen, do: "bg-base-200", else: "bg-primary text-primary-content"}"}>
          <div class="card-body">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <div class="font-bold truncate">
                  <i class={"fa-solid fa-fw #{if e.seen, do: "fa-envelope-open", else: "fa-envelope"}"}></i>
                  <%= e.subject %>
                </div>
                <div class="text-xs opacity-80 truncate"><%= e.from %></div>
                <%= if e[:snippet] do %>
                  <div class="text-xs opacity-60 truncate italic"><%= e.snippet %></div>
                <% end %>
              </div>
              <div class="text-xs opacity-70 shrink-0"><%= e.date %></div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def p_treasury(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <%= if @entries.data == [] do %>
        <div class="text-sm opacity-60">-no pairs-</div>
      <% end %>
      <%= for e <- @entries.data do %>
        <div class="card card-compact w-full bg-primary text-primary-content shadow-xl">
          <div class="card-body">
            <div class="flex items-center justify-between gap-3">
              <div class="min-w-0">
                <div class="font-bold">
                  <i class="fa-solid fa-fw fa-money-bill-transfer"></i> <%= e.pair %>
                </div>
                <%= if e[:from_name] do %>
                  <div class="text-xs opacity-70 truncate"><%= e.from_name %> &rarr; <%= e.to_name %></div>
                <% end %>
              </div>
              <div class="text-right shrink-0">
                <%= if e[:rate] do %>
                  <div class="text-2xl font-mono font-bold"><%= e.display %></div>
                  <%= if e[:date] do %><div class="text-xs opacity-60"><%= e.date %></div><% end %>
                <% else %>
                  <div class="text-sm opacity-70"><%= e[:error] || "unavailable" %></div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def p_bourse(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <%= if @entries.data == [] do %>
        <div class="text-sm opacity-60">-no quote-</div>
      <% end %>
      <%= for e <- @entries.data do %>
        <div class={"card card-compact w-full shadow-xl #{bourse_card(e[:direction])}"}>
          <div class="card-body">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="font-bold">
                  <i class="fa-solid fa-fw fa-chart-line"></i> <%= e.symbol %>
                </div>
                <%= if e[:name] do %>
                  <div class="text-xs opacity-70 truncate"><%= e.name %></div>
                <% end %>
                <%= if e[:exchange] do %>
                  <div class="text-xs opacity-60"><%= e.exchange %><%= if e[:currency], do: " · #{e.currency}" %></div>
                <% end %>
              </div>
              <div class="text-right shrink-0">
                <%= if e[:price] do %>
                  <div class="text-2xl font-mono font-bold"><%= RoomBourse.Worker.format_price(e.price) %></div>
                  <div class="text-xs font-mono">
                    <i class={"fa-solid fa-fw #{bourse_arrow(e[:direction])}"}></i>
                    <%= RoomBourse.Worker.format_change(e[:change]) %>
                    <%= RoomBourse.Worker.format_pct(e[:change_pct]) %>
                  </div>
                <% else %>
                  <div class="text-sm opacity-70"><%= e[:error] || "unavailable" %></div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Colour follows the day's move; unknown or flat stays neutral rather than
  # implying a direction.
  defp bourse_card(:up), do: "bg-success text-success-content"
  defp bourse_card(:down), do: "bg-error text-error-content"
  defp bourse_card(_), do: "bg-base-200"

  defp bourse_arrow(:up), do: "fa-arrow-trend-up"
  defp bourse_arrow(:down), do: "fa-arrow-trend-down"
  defp bourse_arrow(_), do: "fa-minus"

  defp package_icon(carrier) do
    case carrier do
      :ups -> "fa-brands fa-ups fa-fw"
      :fedex -> "fa-brands fa-fedex fa-fw"
      :usps -> "fa-brands fa-usps fa-fw"
      _otherwise -> "fa-solid fa-box fa-fw"
    end
  end

  # One component serves both query modes, since dispatch keys on the source
  # type: a flight watch arrives as a single entry tagged kind=flight.
  def p_icarus(%{entries: %{data: [%{"kind" => "flight"} | _]}} = assigns) do
    ~H"""
    <% w = hd(@entries.data) %>
    <div class="flex flex-col gap-2">
      <div class={"card card-compact w-full shadow-xl #{icarus_status_card(w["status"])}"}>
        <div class="card-body">
          <div class="flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <span class="badge badge-neutral gap-1">
                <i class="fa-solid fa-fw fa-plane-up"></i>
                <%= w["flight_number"] || w["callsign"] %>
              </span>
              <span class="font-bold text-lg"><%= icarus_status_text(w) %></span>
            </div>
            <span class="text-xs opacity-70">to <%= w["dest"] %></span>
          </div>

          <div class="grid grid-cols-3 gap-2 mt-2 text-center">
            <div>
              <div class="text-xs opacity-60 uppercase">scheduled</div>
              <div class="text-lg font-mono"><%= icarus_clock(w["sched_arrival"], w["tz"]) %></div>
            </div>
            <div>
              <div class="text-xs opacity-60 uppercase">
                <%= if w["state"] == "landed", do: "landed", else: "est. landing" %>
              </div>
              <div class="text-lg font-mono">
                <%= icarus_clock(w["landed_at"] || w["eta"], w["tz"]) %>
              </div>
            </div>
            <div>
              <div class="text-xs opacity-60 uppercase">at the curb</div>
              <div class="text-lg font-mono"><%= icarus_clock(w["curb_eta"], w["tz"]) %></div>
            </div>
          </div>

          <%= if w["state"] == "pending" do %>
            <div class="text-xs opacity-70 mt-1">
              Not airborne yet - nothing transmits until it takes off.
            </div>
          <% end %>
          <%= if w["state"] == "expired" do %>
            <div class="text-xs opacity-70 mt-1">
              Never seen inside the tracking window. Check the flight number and date.
            </div>
          <% end %>

          <%= if w["registration"] do %>
            <div class="text-xs opacity-60 mt-1">
              <%= w["registration"] %><%= if w["aircraft_type"], do: " · #{w["aircraft_type"]}" %>
              <%= if w["position"]["dst"], do: " · #{icarus_distance(w["position"]["dst"])} out" %>
            </div>
          <% end %>
        </div>
      </div>
      <div class="text-xs opacity-50">
        data from <a href="https://adsb.fi/" class="link" target="_blank">adsb.fi</a>
      </div>
    </div>
    """
  end

  def p_icarus(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <%= if @entries.data == [] do %>
        <div class="text-sm opacity-60">-no aircraft in range-</div>
      <% end %>
      <%= for ac <- @entries.data do %>
        <div class="card card-compact w-full shadow-xl bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between gap-2">
              <div class="flex items-center gap-2">
                <span class="badge badge-primary gap-1">
                  <i class="fa-solid fa-fw fa-plane-up" style={icarus_rotate(ac["track"])}></i>
                  <%= ac["flight"] || ac["registration"] || ac["hex"] %>
                </span>
                <%= if ac["military"] do %>
                  <span class="badge badge-warning gap-1">
                    <i class="fa-solid fa-fw fa-shield"></i>mil
                  </span>
                <% end %>
                <%= if ac["class"] == "cargo" do %>
                  <span class="badge badge-accent gap-1">
                    <i class="fa-solid fa-fw fa-box"></i>cargo
                  </span>
                <% end %>
                <%= if ac["emergency"] not in [nil, "none"] do %>
                  <span class="badge badge-error"><%= ac["emergency"] %></span>
                <% end %>
              </div>
              <span class="text-xs opacity-70">
                <%= icarus_distance(ac["dst"]) %> <%= icarus_cardinal(ac["dir"]) %>
              </span>
            </div>

            <div class="grid grid-cols-4 gap-2 mt-2 text-center">
              <div>
                <div class="text-xs opacity-60 uppercase">alt</div>
                <div class="text-lg font-mono"><%= icarus_altitude(ac["alt_baro"]) %></div>
              </div>
              <div>
                <div class="text-xs opacity-60 uppercase">speed</div>
                <div class="text-lg font-mono"><%= icarus_speed(ac["gs"]) %></div>
              </div>
              <div>
                <div class="text-xs opacity-60 uppercase">track</div>
                <div class="text-lg font-mono"><%= icarus_track(ac["track"]) %></div>
              </div>
              <div>
                <div class="text-xs opacity-60 uppercase">v/s</div>
                <div class={"text-lg font-mono #{icarus_vs_class(ac["vert_rate"])}"}>
                  <%= icarus_vert_rate(ac["vert_rate"]) %>
                </div>
              </div>
            </div>

            <%= if ac["desc"] || ac["operator"] do %>
              <div class="text-xs opacity-70 mt-1">
                <%= [ac["desc"], ac["operator"]] |> Enum.reject(&is_nil/1) |> Enum.join(" — ") %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      <div class="text-xs opacity-50">
        data from <a href="https://adsb.fi/" class="link" target="_blank">adsb.fi</a>
      </div>
    </div>
    """
  end

  # alt_baro is the string "ground" when the aircraft is on the surface.
  defp icarus_altitude(nil), do: "—"
  defp icarus_altitude("ground"), do: "GND"
  defp icarus_altitude(alt) when is_number(alt), do: "#{round(alt)}'"
  defp icarus_altitude(alt), do: to_string(alt)

  defp icarus_speed(nil), do: "—"
  defp icarus_speed(gs) when is_number(gs), do: "#{round(gs)}kt"
  defp icarus_speed(gs), do: to_string(gs)

  defp icarus_track(nil), do: "—"
  defp icarus_track(track) when is_number(track), do: "#{round(track)}°"
  defp icarus_track(track), do: to_string(track)

  defp icarus_distance(nil), do: "—"
  defp icarus_distance(dst) when is_number(dst), do: "#{:erlang.float_to_binary(dst / 1, decimals: 1)}nm"
  defp icarus_distance(dst), do: to_string(dst)

  defp icarus_vert_rate(nil), do: "—"
  defp icarus_vert_rate(0), do: "level"

  defp icarus_vert_rate(rate) when is_number(rate) do
    sign = if rate > 0, do: "+", else: ""
    "#{sign}#{round(rate)}"
  end

  defp icarus_vert_rate(rate), do: to_string(rate)

  defp icarus_vs_class(rate) when is_number(rate) and rate > 0, do: "text-success"
  defp icarus_vs_class(rate) when is_number(rate) and rate < 0, do: "text-warning"
  defp icarus_vs_class(_), do: ""

  # The plane glyph points north, so rotating by track makes the row read as a
  # compass at a glance -- the whole point of a flight wall.
  defp icarus_rotate(track) when is_number(track), do: "transform: rotate(#{round(track)}deg)"
  defp icarus_rotate(_), do: nil

  defp icarus_cardinal(nil), do: ""

  defp icarus_cardinal(dir) when is_number(dir) do
    ~w(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW)
    |> Enum.at(dir |> Kernel./(22.5) |> round() |> rem(16))
  end

  defp icarus_cardinal(_), do: ""

  defp icarus_status_card("landed"), do: "bg-success text-success-content"
  defp icarus_status_card("early"), do: "bg-success text-success-content"
  defp icarus_status_card("on time"), do: "bg-base-200"
  defp icarus_status_card("delayed"), do: "bg-warning text-warning-content"
  defp icarus_status_card("no sighting"), do: "bg-error text-error-content"
  defp icarus_status_card(_), do: "bg-base-200"

  # Say how early or late, not just that it is -- "delayed 40m" is actionable in
  # a way that "delayed" is not.
  defp icarus_status_text(%{"status" => "landed"}), do: "Landed"
  defp icarus_status_text(%{"status" => "not airborne"}), do: "Not airborne"
  defp icarus_status_text(%{"status" => "no sighting"}), do: "No sighting"
  defp icarus_status_text(%{"status" => "tracking"}), do: "Tracking"

  defp icarus_status_text(%{"status" => status, "delay_minutes" => delay})
       when is_integer(delay) do
    case status do
      "early" -> "Early #{abs(delay)}m"
      "delayed" -> "Delayed #{delay}m"
      _ -> "On time"
    end
  end

  defp icarus_status_text(_), do: "Tracking"

  # Everything on the card reads in the destination airport's local time, which
  # is the clock the ticket is printed in and the one the person waiting at
  # arrivals is looking at.
  defp icarus_clock(nil, _tz), do: "—"

  defp icarus_clock(%DateTime{} = dt, tz) when is_binary(tz) do
    case DateTime.shift_zone(dt, tz, Tzdata.TimeZoneDatabase) do
      {:ok, local} -> Calendar.strftime(local, "%H:%M")
      _ -> Calendar.strftime(dt, "%H:%M") <> "Z"
    end
  end

  defp icarus_clock(%DateTime{} = dt, _tz), do: Calendar.strftime(dt, "%H:%M") <> "Z"
  defp icarus_clock(%NaiveDateTime{} = dt, _tz), do: Calendar.strftime(dt, "%H:%M")
  defp icarus_clock(other, _tz), do: to_string(other)
end
