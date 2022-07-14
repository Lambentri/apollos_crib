defmodule RoomSanctum.Storage.GTFS.Agency do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gtfs_agencies" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :agency_fare_url, :string
    field :agency_id, :string
    field :agency_lang, :string
    field :agency_name, :string
    field :agency_phone, :string
    field :agency_timezone, :string
    field :agency_url, :string
    field :tts_agency_name, :string

    timestamps()
  end

  @doc false
  def changeset(agency, attrs) do
    agency
    |> cast(attrs, [
      :agency_id,
      :agency_url,
      :agency_lang,
      :agency_name,
      :agency_phone,
      :agency_timezone,
      :agency_fare_url,
      :tts_agency_name,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :agency_id,
      :agency_url,
      :agency_lang,
      :agency_name,
      :agency_phone,
      :agency_timezone
    ])
  end
end
