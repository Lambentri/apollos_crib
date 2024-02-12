defmodule RoomSanctum.Storage.GBFS.V1.EbikesAtStations.Ebike.Range do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :estimated_range_miles, :decimal
    field :conservative_range_miles, :decimal
  end

  def changeset(estimates, attrs) do
    estimates
    |> cast(attrs, [:estimated_range_miles, :conservative_range_miles])
    |> validate_required([:estimated_range_miles, :conservative_range_miles])
  end
end

defmodule RoomSanctum.Storage.GBFS.V1.EbikesAtStations.Ebike do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    embeds_one :range_estimate, RoomSanctum.Storage.GBFS.V1.EbikesAtStations.Ebike.Range
    field :displayed_number, :string
    field :rideable_id, :string
    field :docking_capability, :integer
    field :battery_charge_percentage, :integer
    field :make_and_model, :string
    field :is_lbs_internal_rideable, :boolean
  end

  @doc false
  def changeset(ebikes, attrs) do
    ebikes
    |> cast(attrs, [
      :displayed_number,
      :rideable_id,
      :docking_capability,
      :battery_charge_percentage,
      :make_and_model,
      :is_lbs_internal_rideable
    ])
    |> cast_embed(:range_estimate, with: &RoomSanctum.Storage.GBFS.V1.EbikesAtStations.Ebike.Range.changeset/2)
    |> validate_required([
      :displayed_number,
      :rideable_id,
      :docking_capability,
      :battery_charge_percentage,
      :make_and_model,
      :is_lbs_internal_rideable
    ])
  end
end

defmodule RoomSanctum.Storage.GBFS.V1.EbikesAtStations do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_ebikes_stations" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :station_id, :string
    embeds_many :ebikes, RoomSanctum.Storage.GBFS.V1.EbikesAtStations.Ebike

    timestamps()
  end

  @doc false
  def changeset(ebikes_at_stations, attrs) do
    ebikes_at_stations
    |> cast(attrs, [:station_id, :source_id])
    |> foreign_key_constraint(:source_id)
    |> cast_embed(:ebikes, with: &RoomSanctum.Storage.GBFS.V1.EbikesAtStations.Ebike.changeset/2, on_replace: :delete)
    |> validate_required([:station_id])
  end
end
