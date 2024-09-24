defmodule RoomSanctum.Configuration.Source do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  schema "cfg_sources" do
    has_many :mailboxes, RoomSanctum.Configuration.Taxid
    has_many :webhooks, RoomSanctum.Configuration.Agyr
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
        :cronos,
        :gitlab,
        :packages,
      ]

    polymorphic_embeds_one :config,
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
        cronos: RoomSanctum.Configuration.Configs.Cronos,
        gitlab: RoomSanctum.Configuration.Configs.Gitlab,
        packages: RoomSanctum.Configuration.Configs.Packages,
      ],
      on_type_not_found: :raise,
      on_replace: :update

    embeds_one :meta, Meta, on_replace: :delete, primary_key: :false do
      field :last_run, :utc_datetime
      field :run_period, :integer
      field :tint, :string
      embeds_many :tracking, Tracking, on_replace: :delete, primary_key: :false do
        field :number, :string
        field :type, Ecto.Enum, values: [:ups, :fedex, :usps, :uniuni]
        field :entries, {:array, :map}
      end
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
    |> cast(attrs, [:last_run, :run_period, :tint])
    |> cast_embed(:tracking, required: false, with: &tracking_changeset/2)
  end

  def tracking_changeset(meta, attrs \\ %{}) do
    meta
    |> cast(attrs, [:number, :type, :entries])
  end
end
