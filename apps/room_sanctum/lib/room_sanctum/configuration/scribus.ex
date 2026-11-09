defmodule RoomSanctum.Configuration.Scribus do
  use Ecto.Schema
  import Ecto.Changeset

  alias RoomSanctum.Accounts.RabbitUser
  alias RoomSanctum.Configuration.{Ownership, Vision}

  schema "cfg_scribus" do
    field :configuration, {:array, :map}
    field :name, :string
    field :resolution, :string
    field :vision, :id
    field :enabled, :boolean
    field :ankyra, :integer
    field :color, Ecto.Enum, values: [:untouched, :gray16]
    field :wait, :integer, default: 3
    field :buffer, :integer, default: 60
    field :theme, Ecto.Enum, values: [:inky, :color, :her, :afterdark]
    field :show_name, :boolean
    field :show_time, :boolean
    field :tz, :string
    # Set by create_scribus/2 from the signed-in user, never cast.
    belongs_to :user, RoomSanctum.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(scribus, attrs) do
    scribus
    |> cast(attrs, [:name, :resolution, :configuration, :enabled, :ankyra, :color, :wait, :buffer, :theme, :vision])
    |> validate_required([:name, :resolution, :vision, :enabled, :color, :wait, :buffer, :theme])
    # As on a pythiae: only the owner's own vision, shown on their own Ankyra.
    |> Ownership.validate_owned(:vision, Vision)
    |> Ownership.validate_owned(:ankyra, RabbitUser)
  end
end
