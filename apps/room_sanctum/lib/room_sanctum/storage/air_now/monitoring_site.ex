defmodule RoomSanctum.Storage.AirNow.MonitoringSite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "airnow_monitoring_sites" do
    field :agency_id, :string
    field :agency_name, :string
    field :aqsid, :string
    field :cbsa_id, :string
    field :cbsa_name, :string
    field :country_fips, :string
    field :county_aqs_code, :string
    field :county_name, :string
    field :elevation, :float
    field :epa_region, :string
    field :full_aqsid, :string
    field :gmt_offset, :integer
    field :monitor_type, :string
    field :parameters, {:array, :string}
    field :point, Geo.PostGIS.Geometry
    field :site_code, :string
    field :site_name, :string
    field :state_abbreviation, :string
    field :state_aqs_code, :string
    field :station_id, :string
    field :status, Ecto.Enum, values: [:active, :inactive]

    timestamps()
  end

  @doc false
  def changeset(monitoring_site, attrs) do
    monitoring_site
    |> cast(attrs, [:station_id, :aqsid, :full_aqsid, :monitor_type, :parameter, :site_code, :site_name, :status, :agency_id, :agency_name, :epa_region, :point, :elevation, :gmp_offset, :country_fips, :cbsa_id, :cbsa_name, :state_aqs_code, :state_abbreviation, :county_aqs_code, :county_name])
    |> validate_required([:station_id, :aqsid, :full_aqsid, :monitor_type, :parameter, :site_code, :site_name, :status, :agency_id, :agency_name, :epa_region, :point, :elevation, :gmp_offset, :country_fips, :cbsa_id, :cbsa_name, :state_aqs_code, :state_abbreviation, :county_aqs_code, :county_name])
  end
end
