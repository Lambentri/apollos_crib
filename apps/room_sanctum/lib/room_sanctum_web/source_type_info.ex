defmodule RoomSanctumWeb.SourceTypeInfo do
  @moduledoc """
  Human-facing name and one-line description for each source type.

  The bare enum atoms are fine in a `<select>` where the user is already scanning
  a short list, but a picker that shows them side by side needs to say what each
  one actually pulls in.
  """

  alias RoomSanctum.Configuration.Source

  @doc "All source types as `{type, label, description}`, in enum order."
  def all do
    Source
    |> Ecto.Enum.values(:type)
    |> Enum.map(&{&1, label(&1), description(&1)})
  end

  def label(:aqi), do: "Air Quality"
  def label(:calendar), do: "Calendar"
  def label(:cronos), do: "Cronos"
  def label(:drought), do: "Drought"
  def label(:ephem), do: "Ephemeris"
  def label(:gbfs), do: "Bikeshare"
  def label(:github), do: "GitHub"
  def label(:gitlab), do: "GitLab"
  def label(:gtfs), do: "Transit"
  def label(:hass), do: "Home Assistant"
  def label(:icarus), do: "Aircraft"
  def label(:mailbox), do: "Mailbox"
  def label(:bourse), do: "Markets"
  def label(:treasury), do: "Exchange Rates"
  def label(:packages), do: "Packages"
  def label(:pollen), do: "Pollen"
  def label(:rideshare), do: "Rideshare"
  def label(:tidal), do: "Tides"
  def label(:weather), do: "Weather"
  def label(other), do: other |> to_string() |> String.capitalize()

  def description(:aqi), do: "AirNow air quality readings and forecasts."
  def description(:calendar), do: "Events from any iCal feed."
  def description(:cronos), do: "Countdowns and fixed points in time."
  def description(:drought), do: "US Drought Monitor conditions by county or state."
  def description(:ephem), do: "Sun and moon rise, set, and phase."
  def description(:gbfs), do: "Bikeshare docks, e-bikes, and free-floating vehicles."
  def description(:github), do: "Repository commits and activity."
  def description(:gitlab), do: "Project commits and activity."
  def description(:gtfs), do: "Transit schedules, plus realtime arrivals where offered."
  def description(:hass), do: "Entities from a Home Assistant instance."
  def description(:icarus), do: "Live aircraft overhead, or one arrival tracked to the gate."
  def description(:mailbox), do: "An IMAP account other sources can pull mail from."
  def description(:bourse), do: "Stock, ETF, index and crypto quotes from Yahoo Finance."
  def description(:treasury), do: "Currency, crypto and metal prices for any pair."
  def description(:packages), do: "Parcel tracking for UPS, FedEx, USPS, and UniUni."
  def description(:pollen), do: "Google pollen forecasts by species."
  def description(:rideshare), do: "Nearby rideshare availability and pricing."
  def description(:tidal), do: "Tide predictions for a coastal station."
  def description(:weather), do: "OpenWeather current conditions and forecast."
  def description(_), do: ""
end
