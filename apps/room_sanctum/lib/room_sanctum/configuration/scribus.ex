defmodule RoomSanctum.Configuration.Scribus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_scribus" do
    field :configuration, {:array, :map}
    field :name, :string
    field :resolution, :string
    field :vision, :id

    timestamps()
  end

  @doc false
  def changeset(scribus, attrs) do
    scribus
    |> cast(attrs, [:name, :resolution, :configuration])
    |> validate_required([:name, :resolution, :configuration])
  end
end
