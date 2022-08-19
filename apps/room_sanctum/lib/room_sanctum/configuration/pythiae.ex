defmodule RoomSanctum.Configuration.Pythiae do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_pythiae" do
    field :name, :string
    field :ankyra, {:array, :integer}
    field :visions, {:array, :integer}
    belongs_to :user, RoomSanctum.Accounts.User
    field :curr_vision, :id
    field :curr_foci, :id

    timestamps()
  end

  @doc false
  def changeset(pythiae, attrs) do
    pythiae
    |> cast(attrs, [:visions, :ankyra, :user_id, :curr_vision, :curr_foci, :name])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:curr_vision)
    |> foreign_key_constraint(:curr_foci)
    |> validate_required([:visions, :ankyra, :name])
  end
end
