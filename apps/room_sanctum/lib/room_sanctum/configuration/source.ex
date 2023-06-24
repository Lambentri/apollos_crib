defmodule RoomSanctum.Configuration.Source do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed, only: [cast_polymorphic_embed: 3]

  schema "cfg_sources" do
    belongs_to :user, RoomSanctum.Accounts.User
    field :enabled, :boolean, default: false
    field :public, :boolean, default: true
    field :name, :string
    field :notes, :string

    field :type, Ecto.Enum,
      values: [
        :aqi,
        :calendar,
        :ephem,
        :gbfs,
        :gtfs,
        :hass,
        :rideshare,
        :tidal,
        :weather,
        :cronos
      ]

    field :config, PolymorphicEmbed,
      types: [
        aqi: RoomSanctum.Configuration.Configs.AQI,
        calendar: RoomSanctum.Configuration.Configs.Calendar,
        ephem: RoomSanctum.Configuration.Configs.Ephem,
        gbfs: RoomSanctum.Configuration.Configs.GBFS,
        gtfs: RoomSanctum.Configuration.Configs.GTFS,
        hass: RoomSanctum.Configuration.Configs.Hass,
        rideshare: RoomSanctum.Configuration.Configs.Rideshare,
        tidal: RoomSanctum.Configuration.Configs.Tidal,
        weather: RoomSanctum.Configuration.Configs.Weather,
        email: [module: MyApp.Channel.Email, identify_by_fields: [:address, :confirmed]],
        cronos: RoomSanctum.Configuration.Configs.Cronos
      ],
      on_type_not_found: :raise,
      on_replace: :update

    embeds_one :meta, Meta, on_replace: :delete, primary_key: :false do
      field :last_run, :utc_datetime
      field :run_period, :integer
    end

    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :notes, :type, :enabled, :user_id])
    |> cast_embed(:meta, required: false, with: &meta_changeset/2)
    |> foreign_key_constraint(:user_id)
    |> cast_polymorphic_embed(:config, required: true)
    |> validate_required([:name, :type, :enabled, :user_id])
  end

  def meta_changeset(meta, attrs \\ %{}) do
    meta
    |> cast(attrs, [:last_run, :run_period])
  end
end
