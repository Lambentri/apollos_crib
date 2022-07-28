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
    end
  end
end