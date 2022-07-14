defmodule RoomSanctum.Storage.AirNow.HourlyData do
  use Ecto.Schema
  import Ecto.Changeset

  schema "airnow_hourly_data" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :aqsid, :string
    field :data_source, :string
    field :gmt_offset, :integer
    field :parameter_name, :string
    field :reporting_units, :string
    field :site_name, :string
    field :valid_date, :date
    field :valid_time, :time
    field :value, :integer

    timestamps()
  end

  @doc false
  def changeset(hourly_data, attrs) do
    hourly_data
    |> cast(attrs, [
      :valid_date,
      :valid_time,
      :aqsid,
      :site_name,
      :gmt_offset,
      :parameter_name,
      :reporting_units,
      :value,
      :data_source,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :valid_date,
      :valid_time,
      :aqsid,
      :site_name,
      :gmt_offset,
      :parameter_name,
      :reporting_units,
      :value,
      :data_source
    ])
  end
end
