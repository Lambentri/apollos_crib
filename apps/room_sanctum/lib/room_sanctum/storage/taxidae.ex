defmodule RoomSanctum.Storage.Taxidae do
  use Ecto.Schema
  import Ecto.Changeset

  schema "storage_mail" do
    field :meta, :map
    field :body_plain, :string
    field :body_html, :string
    belongs_to :mail, RoomSanctum.Configuration.Taxid

    timestamps()
  end

  @doc false
  def changeset(taxidae, attrs) do
    taxidae
    |> cast(attrs, [:meta, :body_plain, :body_html])
    |> validate_required([:meta])
  end
end
