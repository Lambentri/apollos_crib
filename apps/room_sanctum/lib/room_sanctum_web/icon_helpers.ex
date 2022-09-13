defmodule RoomSanctumWeb.IconHelpers do
  def icon(source_type) do
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
      :cronos ->
        "fa-clock"
    end
  end

  def icon_code(source_type) do
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
      :cronos ->
        "f017"
    end
  end
end