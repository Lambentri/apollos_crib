defmodule RoomSanctum.Configuration.Pythiae.Tweaks do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :ttl, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(ttl)a)
    |> validate_required(:ttl)
  end
end

alias RoomSanctum.Configuration.Pythiae.Tweaks

defmodule RoomSanctum.Configuration.Pythiae.Const do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :title, :string
    field :body, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(title body)a)
    |> validate_required([:title, :body])
  end
end

alias RoomSanctum.Configuration.Pythiae.Const

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
    embeds_many :consts, Const
    embeds_one :tweaks, Tweaks

    timestamps()
  end

  @doc false
  def changeset(pythiae, attrs) do
    pythiae
    |> cast(attrs, [:visions, :ankyra, :user_id, :curr_vision, :curr_foci, :name])
    |> cast_embed(:consts, with: &Const.changeset/2)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:curr_vision)
    |> foreign_key_constraint(:curr_foci)
    |> validate_required([:visions, :ankyra, :name])
  end
end
