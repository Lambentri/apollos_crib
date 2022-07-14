defmodule RoomSanctum.Storage.AirNow.ReportingArea do
  use Ecto.Schema
  import Ecto.Changeset

  schema "airnow_reporting_area" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :action_day, :boolean, default: false
    field :aqi_category, :string
    field :aqi_value, :integer
    field :data_type, Ecto.Enum, values: [:F, :Y, :O]
    field :discussion, :string
    field :forecast_source, :string
    field :issue_date, :date
    field :lat, :float
    field :lon, :float
    field :parameter_name, :string
    field :primary, Ecto.Enum, values: [:Y, :N]
    field :record_sequence, :integer
    field :reporting_area, :string
    field :state_code, :string
    field :time_zone, :string
    field :valid_date, :date
    field :valid_time, :time

    timestamps()
  end

  @doc false
  def changeset(reporting_area, attrs) do
    reporting_area
    |> cast(attrs, [
      :issue_date,
      :valid_date,
      :valid_time,
      :time_zone,
      :record_sequence,
      :data_type,
      :primary,
      :reporting_area,
      :state_code,
      :lat,
      :lon,
      :parameter_name,
      :aqi_value,
      :aqi_category,
      :action_day,
      :discussion,
      :forecast_source,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :issue_date,
      :valid_date,
      :valid_time,
      :time_zone,
      :record_sequence,
      :data_type,
      :primary,
      :reporting_area,
      :state_code,
      :lat,
      :lon,
      :parameter_name,
      :aqi_value,
      :aqi_category,
      :action_day,
      :discussion,
      :forecast_source
    ])
  end
end
