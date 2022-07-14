defmodule RoomSanctum.Storage.GBFS.V1.SysInfo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_system_information" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :email, :string
    field :language, :string
    field :license_url, :string
    field :name, :string
    field :operator, :string
    field :phone_number, :string
    field :purchase_url, :string
    field :short_name, :string
    field :start_date, :date
    field :system_id, :string
    field :timezone, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(sys_info, attrs) do
    sys_info
    |> cast(attrs, [
      :name,
      :email,
      :timezone,
      :short_name,
      :phone_number,
      :language,
      :start_date,
      :url,
      :operator,
      :purchase_url,
      :license_url,
      :system_id,
      :source_id
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([
      :name,
      :email,
      :timezone,
      :short_name,
      :phone_number,
      :language,
      :start_date,
      :url,
      :operator,
      :purchase_url,
      :license_url,
      :system_id
    ])
  end
end
