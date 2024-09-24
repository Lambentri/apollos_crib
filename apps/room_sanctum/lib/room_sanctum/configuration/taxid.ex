defmodule RoomSanctum.Configuration.Taxid do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_mailboxes" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :user, :string
    field :designator, :string

    timestamps()
  end

  @doc false
  def changeset(taxid, attrs) do
    taxid
    |> cast(attrs, [:designator, :user])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:designator, :user])
  end
end
