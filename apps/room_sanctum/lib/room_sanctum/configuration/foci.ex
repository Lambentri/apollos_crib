defmodule RoomSanctum.Configuration.Foci do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_focis" do
    field :name, :string
    field :place, Geo.PostGIS.Geometry
    belongs_to :user, RoomSanctum.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(foci, attrs) do
    foci
    |> cast(attrs, [:name, :place, :user_id])
    |> foreign_key_constraint(:user_id)
    |> validate_required([:name, :place])
  end
end
