defmodule RoomSanctum.Storage.GBFS.V1.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_alerts" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :alert_id, :string
    field :description, :string
    field :last_updated, :utc_datetime
    field :region_ids, {:array, :string}
    field :station_ids, {:array, :string}
    field :summary, :string
    field :times, {:array, :integer}
    field :type, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :alert_id,
      :type,
      :times,
      :station_ids,
      :region_ids,
      :url,
      :summary,
      :description,
      :last_updated,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :alert_id,
      :type,
      :times,
      :station_ids,
      :region_ids,
      :url,
      :summary,
      :description,
      :last_updated
    ])
  end
end
