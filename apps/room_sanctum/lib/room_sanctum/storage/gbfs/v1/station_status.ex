defmodule RoomSanctum.Storage.GBFS.V1.StationStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_station_status" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :is_installed, :boolean, default: false
    field :is_renting, :boolean, default: false
    field :is_returning, :boolean, default: false
    field :last_reported, :utc_datetime
    field :legacy_id, :string
    field :num_bikes_available, :integer
    field :num_bikes_disables, :integer
    field :num_docks_available, :integer
    field :num_docks_disabled, :integer
    field :num_ebikes_available, :integer
    field :station_id, :string
    field :station_status, :string

    timestamps()
  end

  @doc false
  def changeset(station_status, attrs) do
    station_status
    |> cast(attrs, [:legacy_id, :num_bikes_available, :num_docks_disabled, :station_id, :station_status, :num_bikes_disables, :last_reported, :is_installed, :is_renting, :num_ebikes_available, :num_docks_available, :is_returning, :source_id])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:legacy_id, :num_bikes_available, :num_docks_disabled, :station_id, :station_status, :num_bikes_disables, :last_reported, :is_installed, :is_renting, :num_ebikes_available, :num_docks_available, :is_returning])
  end
end
