defmodule RoomSanctum.Configuration.Query do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed, only: [cast_polymorphic_embed: 3]

  schema "cfg_queries" do
    field :name, :string
    field :notes, :string
    field :query, PolymorphicEmbed,
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
            email: [module: MyApp.Channel.Email, identify_by_fields: [:address, :confirmed]]
          ],
          on_type_not_found: :raise,
          on_replace: :update

    belongs_to :source, RoomSanctum.Configuration.Source

    timestamps()
  end

  @doc false
  def changeset(query, attrs) do
    query
    |> cast(attrs, [:name, :notes, :source_id]) |> IO.inspect
    |> foreign_key_constraint(:source_id) |> IO.inspect
    |> cast_polymorphic_embed(:query, required: true) |> IO.inspect
    |> validate_required([:name, :notes]) |> IO.inspect
  end
end
