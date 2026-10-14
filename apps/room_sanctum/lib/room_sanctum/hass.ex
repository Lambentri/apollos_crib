defmodule RoomSanctum.Hass do
  @moduledoc """
  Home Assistant's MQTT discovery, for what an Ankyra or a Keryx already
  publishes.

  Nothing new is published as state. Every entity here is a template over a
  payload that is already on the broker -- the board on an Ankyra's topic, or a
  Keryx query's `.meta` -- so Home Assistant reads exactly what a panel or a
  phone reads, and a board that changes shape changes for all of them at once.

  One device per query, with an entity for each thing in it worth a sensor: a
  route and direction at a stop, a dock, a pollutant. Each is picked out of the
  payload by what it is rather than where it sits, since a route with nothing
  due drops out of the list and everything after it would move up.

  The discovery prefix lives under the Ankyra's own topic, `<topic>/ha`. A
  rabbit user may read only its own topic and the Keryxiae its account owns,
  so `homeassistant/` is not somewhere Home Assistant could subscribe to here;
  it is told to look in `<topic>/ha` instead. Clients subscribe to the topic
  itself rather than to `<topic>/#`, so nothing else sees these.
  """

  @origin %{name: "Apollo's Crib"}

  @doc "Where the discovery prefix sits under an Ankyra's routing key."
  def prefix(ankyra_topic), do: ankyra_topic <> ".ha"

  @doc "The routing key one device's config is published on."
  def config_key(ankyra_topic, object_id), do: "#{prefix(ankyra_topic)}.device.#{object_id}.config"

  @doc """
  Devices for a board an Ankyra is publishing.

  `reading` says which topic the board went out on -- the Plus board is on
  `<topic>.plus` and is the one read wherever a Pythiae publishes it, since it
  carries everything Basic does and more.

  Ids are built from the query rather than the board key, so a Pythiae that
  turns Plus on keeps its devices: `gtfs-3` and `gtfs_plus-3` are the same stop.
  """
  def board_devices(ankyra_id, ankyra_topic, board, reading \\ :basic) do
    state_topic = mqtt_topic(if reading == :plus, do: ankyra_topic <> ".plus", else: ankyra_topic)

    for {key, entry} <- board, entry not in [nil, %{}] do
      key = to_string(key)
      [type, id] = String.split(key, "-", parts: 2)

      device(
        "apollos_a#{ankyra_id}_#{base_type(type)}_#{slug(id)}",
        type,
        entry,
        %{state_topic: state_topic},
        "{% set e = value_json.get(#{lit(key)}) %}"
      )
    end
  end

  @doc """
  The device for one Keryx query, read off its `.meta` topic.

  A Keryx publishes every thirty seconds whatever has changed, so these expire
  when it stops: a stale bus time is worse than none.
  """
  def keryx_device(keryx_id, query_id, type, meta) do
    device(
      "apollos_k#{keryx_id}_#{slug(query_id)}",
      to_string(type),
      meta,
      %{
        state_topic: mqtt_topic("#{RoomSanctum.Configuration.Keryx.topic(keryx_id)}.#{type}.#{query_id}.meta"),
        expire_after: 300
      },
      "{% set e = value_json %}"
    )
  end

  # What a routing key looks like to an MQTT client.
  defp mqtt_topic(key), do: String.replace(key, ".", "/")

  defp base_type("gtfs_plus"), do: "gtfs"
  defp base_type(type), do: type

  defp device(object_id, type, entry, shared, root) do
    query = get(entry, :query) || %{}
    data = List.wrap(get(entry, :data))

    components =
      type
      |> components(data, root)
      |> Map.new(fn {id, cfg} ->
        {id, Map.merge(%{platform: "sensor", unique_id: "#{object_id}_#{id}"}, cfg)}
      end)

    {object_id,
     Map.merge(shared, %{
       device: %{
         identifiers: [object_id],
         name: get(query, :name) || object_id,
         manufacturer: "Apollo's Crib",
         model: model(type)
       },
       origin: @origin,
       components: components
     })}
  end

  # -- Per type ---------------------------------------------------------------

  # A route, a destination and a direction: one line on a stop's sign. The next
  # departure is live where the feed has an estimate and scheduled where not,
  # which is what the board itself would show -- and the first that has not
  # gone, since a board can still be listing one that left a minute ago.
  defp components(type, data, root) when type in ["gtfs", "gtfs_plus"] do
    for r <- data, is_map(r) do
      pick =
        "{% set d = (e.data | selectattr('route', 'eq', #{lit(get(r, :route))})" <>
          " | selectattr('dest', 'eq', #{lit(get(r, :dest))})" <>
          " | selectattr('dir', 'eq', #{lit(get(r, :dir))}) | list | first) if e else none %}"

      each =
        if type == "gtfs_plus",
          do: "{% for a in d.arrivals or [] %}{% set x = a.get('time_live') or a.get('time') %}",
          else:
            "{% set lv = d.get('times_live') or [] %}{% for s in d.get('times') or [] %}" <>
              "{% set x = (lv[loop.index0] if lv | length > loop.index0 else none) or s %}"

      next =
        "{% set ns = namespace(t=none) %}" <>
          each <>
          "{% if ns.t is none and x %}" <>
          clock("x", wrap: true) <>
          "{% if t > now() - timedelta(minutes=1) %}{% set ns.t = t %}{% endif %}{% endif %}{% endfor %}"

      {slug("#{get(r, :route)}_#{get(r, :dest)}_#{get(r, :dir)}"),
       %{
         name: "#{get(r, :route_name) || get(r, :route)} to #{get(r, :dest)}",
         icon: mode_icon(get(r, :mode)),
         device_class: "timestamp",
         value_template:
           root <> pick <> "{% if d %}" <> next <>
             "{{ ns.t.isoformat() if ns.t else None }}{% else %}None{% endif %}",
         json_attributes_template: root <> pick <> "{{ (d or {}) | tojson }}"
       }}
    end
  end

  # A dock: what can be taken from it and what can be left at it. A loose bike
  # is not here -- it has moved on by the next board.
  defp components("gbfs", data, root) do
    for s <- data, is_map(s), get(s, :kind) not in [:free_bike, "free_bike"], get(s, :id) != nil,
        {field, label, icon} <- [
          {:avail, "bikes", "mdi:bicycle"},
          {:avail_elec, "e-bikes", "mdi:bicycle-electric"},
          {:docks_avail, "docks", "mdi:parking"}
        ] do
      pick = "{% set d = (e.data | selectattr('id', 'eq', #{lit(get(s, :id))}) | list | first) if e else none %}"

      {slug("#{get(s, :id)}_#{field}"),
       %{
         name: "#{get(s, :name)} #{label}",
         icon: icon,
         state_class: "measurement",
         value_template: root <> pick <> "{{ d.get(#{lit(field)}) if d else None }}",
         json_attributes_template: root <> pick <> "{{ (d or {}) | tojson }}"
       }}
    end
  end

  # Each reporting area, each pollutant it measures. AirNow publishes these as
  # an index rather than a concentration, which is HA's `aqi`.
  defp components("aqi", data, root) do
    for a <- data, is_map(a), {k, v} <- a, is_number(v) do
      pick = "{% set d = (e.data | selectattr('name', 'eq', #{lit(get(a, :name))}) | list | first) if e else none %}"

      {slug("#{get(a, :name)}_#{k}"),
       %{
         name: "#{get(a, :name)} #{aqi_label(k)}",
         device_class: "aqi",
         state_class: "measurement",
         value_template: root <> pick <> "{{ d.get(#{lit(k)}) if d else None }}"
       }}
    end
  end

  defp components("weather", data, root) do
    for w <- data, is_map(w),
        {field, label, extra} <- weather_fields(get(w, :units)) do
      pick = "{% set d = (e.data | selectattr('name', 'eq', #{lit(get(w, :name))}) | list | first) if e else none %}"

      value =
        case field do
          :wind -> "{{ (d.get('wind') or {}).get('speed') if d else None }}"
          f -> "{{ d.get(#{lit(f)}) if d else None }}"
        end

      {slug("#{get(w, :name)}_#{field}"),
       Map.merge(%{name: "#{get(w, :name)} #{label}", value_template: root <> pick <> value}, extra)}
    end
  end

  # The day's highs and lows, as times today. Not wrapped onto tomorrow: once
  # the second high has passed there is no third in the payload to show.
  defp components("tidal", [tides | _], root) when is_map(tides) do
    for {time_key, label} <- [first_h: "First high tide", second_h: "Second high tide",
                              first_l: "First low tide", second_l: "Second low tide"],
        get(tides, time_key) != nil do
      height = "#{time_key}v"

      {to_string(time_key),
       %{
         name: label,
         icon: "mdi:waves",
         device_class: "timestamp",
         value_template:
           root <> "{% set d = (e.data or [{}])[0] if e else {} %}{% set x = d.get(#{lit(time_key)}) %}" <>
             "{% if x %}" <> clock("x") <> "{{ t.isoformat() }}{% else %}None{% endif %}",
         json_attributes_template:
           root <> "{% set d = (e.data or [{}])[0] if e else {} %}{{ {'height': d.get(#{lit(height)})} | tojson }}"
       }}
    end
  end

  # Sun and moon. Home Assistant knows the sun already; the moon's phase and
  # times are the part it does not.
  defp components("ephem", [ephem | _], root) when is_map(ephem) do
    root = root <> "{% set d = (e.data or [{}])[0] if e else {} %}"

    phase =
      if get(ephem, :phase),
        do: [{"phase", %{name: "Moon phase", icon: "mdi:moon-waxing-crescent", value_template: root <> "{{ d.get('phase') }}"}}],
        else: []

    times =
      for k <- [:sunrise, :sunset, :moonrise, :moonset], get(ephem, k) != nil do
        {to_string(k),
         %{
           name: k |> to_string() |> String.capitalize(),
           device_class: "timestamp",
           value_template:
             root <> "{% set x = d.get(#{lit(k)}) %}{% if x %}" <> clock("x") <>
               "{{ t.isoformat() }}{% else %}None{% endif %}"
         }}
      end

    phase ++ times
  end

  # Everything else is a list of things without one obvious number in it: how
  # many there are, and the first few of them to read.
  defp components(_type, _data, root) do
    [
      {"items",
       %{
         name: "Items",
         icon: "mdi:format-list-bulleted",
         state_class: "measurement",
         value_template: root <> "{{ (e.data or []) | length if e else None }}",
         json_attributes_template: root <> "{{ {'items': ((e.data or []) if e else [])[:20]} | tojson }}"
       }}
    ]
  end

  defp weather_fields(units) do
    {temp, speed} =
      case to_string(units) do
        "imperial" -> {"°F", "mph"}
        "metric" -> {"°C", "m/s"}
        _ -> {"K", "m/s"}
      end

    measured = %{state_class: "measurement"}

    [
      {:weather, "conditions", %{icon: "mdi:weather-partly-cloudy"}},
      {:temp, "temperature", Map.merge(measured, %{device_class: "temperature", unit_of_measurement: temp})},
      {:feel, "feels like", Map.merge(measured, %{device_class: "temperature", unit_of_measurement: temp})},
      {:hum, "humidity", Map.merge(measured, %{device_class: "humidity", unit_of_measurement: "%"})},
      {:pressure, "pressure",
       Map.merge(measured, %{device_class: "atmospheric_pressure", unit_of_measurement: "hPa"})},
      {:wind, "wind", Map.merge(measured, %{device_class: "wind_speed", unit_of_measurement: speed})}
    ]
  end

  # -- Templates --------------------------------------------------------------

  @doc """
  Jinja that turns the clock time in `var` -- "17:14:12", "18:04:07.753",
  "14:25" -- into `t`, a datetime today.

  Built from midnight rather than with `today_at`, which refuses a GTFS time
  past 24:00 and anything with a fraction of a second. `wrap: true` moves a
  time more than twelve hours off onto the neighbouring day, for a departure
  list that crosses midnight: 00:10 read at 23:50 is tomorrow, not this
  morning.

  The times are the feed's own local time, and Home Assistant reads them in
  its own. They agree as long as the two are in the same place.
  """
  def clock(var, opts \\ []) do
    base =
      "{% set p = (#{var} ~ '').split(':') %}" <>
        "{% set t = today_at() + timedelta(hours=p[0] | int, minutes=p[1] | int, " <>
        "seconds=(p[2] if p | length > 2 else 0) | float) %}"

    if opts[:wrap] do
      base <>
        "{% set t = t + timedelta(days=(1 if t < now() - timedelta(hours=12) " <>
        "else (-1 if t > now() + timedelta(hours=12) else 0))) %}"
    else
      base
    end
  end

  # A Jinja string literal. JSON's escaping is a subset Jinja reads the same.
  defp lit(value) when is_atom(value) and not is_nil(value), do: lit(Atom.to_string(value))
  defp lit(nil), do: "none"
  defp lit(value) when is_number(value), do: to_string(value)
  defp lit(value), do: Jason.encode!(to_string(value))

  defp slug(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  # Condensed in Elixir with atom keys, or decoded from somewhere with string
  # ones -- the types that pass their source's answer straight through do.
  defp get(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp get(_, _), do: nil

  defp aqi_label(k) do
    case to_string(k) do
      "pm25" -> "PM2.5"
      "pm10" -> "PM10"
      "ozone" -> "ozone"
      other -> String.upcase(other)
    end
  end

  defp mode_icon(mode) do
    case to_string(mode) do
      "Bus" -> "mdi:bus"
      "Trolleybus" -> "mdi:bus-electric"
      "Subway" -> "mdi:subway-variant"
      "LightRail" -> "mdi:tram"
      "Rail" -> "mdi:train"
      "Ferry" -> "mdi:ferry"
      _ -> "mdi:transit-connection-variant"
    end
  end

  defp model("gtfs_plus"), do: "Transit (Plus)"
  defp model("gtfs"), do: "Transit"
  defp model("gbfs"), do: "Bike share"
  defp model("aqi"), do: "Air quality"
  defp model(type), do: type |> String.capitalize()
end
