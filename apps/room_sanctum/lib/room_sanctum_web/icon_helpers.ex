defmodule RoomSanctumWeb.IconHelpers do
  # Font Awesome class and codepoint for each source type. An unknown type
  # raises, as the case these replace did.
  @icons %{
    calendar: "fa-calendar-alt",
    rideshare: "fa-taxi",
    hass: "fa-home",
    gtfs: "fa-bus-alt",
    gbfs: "fa-bicycle",
    tidal: "fa-water",
    ephem: "fa-moon",
    weather: "fa-cloud-sun",
    aqi: "fa-lungs",
    cronos: "fa-clock",
    gitlab: "fa-code-branch",
    github: "fa-github",
    drought: "fa-sun-plant-wilt",
    pollen: "fa-seedling",
    icarus: "fa-plane-up",
    mailbox: "fa-inbox",
    treasury: "fa-money-bill-transfer",
    bourse: "fa-chart-line",
    packages: "fa-envelopes-bulk",
    const: "fa-triangle-exclamation"
  }

  @icon_codes %{
    calendar: "f073",
    rideshare: "f1ba",
    hass: "f015",
    gtfs: "f55e",
    gbfs: "f206",
    tidal: "f773",
    ephem: "f186",
    weather: "f6c4",
    aqi: "f604",
    cronos: "f017",
    gitlab: "f126",
    github: "f09b",
    drought: "e5c8",
    pollen: "f4d8",
    icarus: "e22d",
    mailbox: "f01c",
    treasury: "e528",
    bourse: "f201",
    const: "f071",
    packages: "f674"
  }

  def icon(source_type), do: Map.fetch!(@icons, source_type)

  def icon_code(source_type), do: Map.fetch!(@icon_codes, source_type)
end
