defmodule RoomSanctum.Configuration.Query do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  schema "cfg_queries" do
    belongs_to :user, RoomSanctum.Accounts.User
    field :name, :string
    field :notes, :string

    polymorphic_embeds_one :query,
      types: [
        aqi: RoomSanctum.Configuration.Queries.AQI,
        calendar: RoomSanctum.Configuration.Queries.Calendar,
        ephem: RoomSanctum.Configuration.Queries.Ephem,
        gbfs: RoomSanctum.Configuration.Queries.GBFS,
        gtfs: RoomSanctum.Configuration.Queries.GTFS,
        hass: RoomSanctum.Configuration.Queries.Hass,
        rideshare: RoomSanctum.Configuration.Queries.Rideshare,
        tidal: RoomSanctum.Configuration.Queries.Tidal,
        weather: RoomSanctum.Configuration.Queries.Weather,
        email: [module: MyApp.Channel.Email, identify_by_fields: [:address, :confirmed]],
        cronos: RoomSanctum.Configuration.Queries.Cronos,
        gitlab: RoomSanctum.Configuration.Queries.Gitlab,
        packages: RoomSanctum.Configuration.Queries.Packages,
      ],
      on_type_not_found: :raise,
      on_replace: :update

    belongs_to :source, RoomSanctum.Configuration.Source

    field :geom, Geo.PostGIS.Geometry
    field :public, :boolean, default: true

    embeds_one :meta, Meta, on_replace: :delete, primary_key: :false do
      field :tint, :string
    end

    timestamps()
  end

  @doc false
  def changeset(query, attrs) do
    query
    |> cast(attrs, [:name, :notes, :source_id, :user_id])
    |> cast_embed(:meta, required: false, with: &meta_changeset/2)
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:user_id)
    |> cast_polymorphic_embed(:query, required: true)
    |> validate_required([:name])
  end

  def meta_changeset(meta, attrs \\ %{}) do
    meta
    |> cast(attrs, [:tint])
  end
end
