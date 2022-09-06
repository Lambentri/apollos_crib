defmodule RoomSanctum.Storage.AirNow.HourlyObsData do
  use Ecto.Schema
  import Ecto.Changeset

  schema "airnow_hourly_observations" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :pm10, :float
    field :valid_date, :date
    field :ozone_measured, :boolean, default: false
    field :country_code, :string
    field :ozone_aqi, :integer
    field :state_name, :string
    field :pm10_measured, :boolean, default: false
    field :gmt_offset, :float
    field :co_unit, :string
    field :point, Geo.PostGIS.Geometry
    field :so2, :float
    field :pm25, :float
    field :no2_aqi, :integer
    field :reporting_areas, {:array, :string}
    field :site_name, :string
    field :elevation, :float
    field :data_source, :string
    field :pm25_measured, :boolean, default: false
    field :so2_unit, :string
    field :valid_time, :time
    field :ozone_unit, :string
    field :lon, :float
    field :lat, :float
    field :epa_region, :string
    field :pm25_unit, :string
    field :ozone, :float
    field :aqsid, :string
    field :status, :string
    field :pm10_aqi, :integer
    field :no2_measured, :boolean, default: false
    field :pm10_unit, :string
    field :co, :float
    field :pm25_aqi, :integer
    field :no2, :float
    field :no2_unit, :string

    timestamps()
  end

  @doc false
  def changeset(hourly_obs_data, attrs) do
    hourly_obs_data
    |> cast(attrs, [
      :aqsid,
      :site_name,
      :status,
      :epa_region,
      :lat,
      :lon,
      :point,
      :elevation,
      :gmt_offset,
      :country_code,
      :state_name,
      :valid_date,
      :valid_time,
      :data_source,
      :reporting_areas,
      :ozone_aqi,
      :pm10_aqi,
      :pm25_aqi,
      :no2_aqi,
      :ozone_measured,
      :pm10_measured,
      :pm25_measured,
      :no2_measured,
      :no2,
      :no2_unit,
      :pm25,
      :pm25_unit,
      :ozone,
      :ozone_unit,
      :co,
      :co_unit,
      :so2,
      :so2_unit,
      :pm10,
      :pm10_unit,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :aqsid,
      :site_name,
      :status,
      :lat,
      :lon,
      :point,
      :elevation,
      :state_name,
      :valid_date,
      :valid_time,
      :data_source,
      :reporting_areas,
      :ozone_measured,
      :pm10_measured,
      :pm25_measured,
      :no2_measured
    ])
  end

  def compile_pairs(entry) do
    r = %{combined: ""}
    r = if Map.get(entry, :ozone_measured) do
      r |> Map.put(:ozone, entry.ozone_aqi)
        |> Map.put(:combined, r.combined <> "O2: #{entry.ozone_aqi}, ")
      else
      r
    end
    r = if Map.get(entry, :pm25_measured) do
      r |> Map.put(:pm25, entry.pm25_aqi)
        |> Map.put(:combined, r.combined <> "PM2.5: #{entry.pm25_aqi}, ")
    else
      r
    end
    r = if Map.get(entry, :pm10_measured) do
      r |> Map.put(:pm10, entry.pm10_aqi)
      |> Map.put(:combined, r.combined <> "PM10: #{entry.pm10_aqi}, ")
    else
      r
    end
    r = if Map.get(entry, :no2_measured) do
      r |> Map.put(:no2, entry.no2_aqi)
      |> Map.put(:combined, r.combined <> "NO2: #{entry.no2_aqi}, ")
    else
      r
    end
    r
  end
end
