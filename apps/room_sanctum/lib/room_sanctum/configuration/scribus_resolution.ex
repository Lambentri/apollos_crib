defmodule RoomSanctum.Configuration.ScribusResolution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_scribus_resolutions" do
    field :name, :string
    field :width, :integer
    field :height, :integer
    belongs_to :user, RoomSanctum.Accounts.User

    timestamps()
  end

  def changeset(resolution, attrs) do
    resolution
    |> cast(attrs, [:name, :width, :height, :user_id])
    |> validate_required([:name, :width, :height, :user_id])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> unique_constraint([:user_id, :name])
  end

  def display(%__MODULE__{width: w, height: h, name: name}),
    do: "#{name} (#{w}x#{h})"

  def to_resolution_string(%__MODULE__{width: w, height: h}), do: "#{w}x#{h}"
end
