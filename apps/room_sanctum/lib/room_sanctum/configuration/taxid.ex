defmodule RoomSanctum.Configuration.Taxid do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  A routing designator under a source: what to do with mail once it arrives.

  Credentials do not live here. Mail reaches the system either through the SMTP
  listener (matched on `user`, the local part of the To address) or by being
  pulled from a `:mailbox` source, which owns the IMAP connection.
  """

  schema "cfg_mailboxes" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :user, :string
    field :designator, :string

    timestamps()
  end

  @doc false
  def changeset(taxid, attrs) do
    taxid
    |> cast(attrs, [
      # source_id was missing here, so create_taxid/1 silently produced
      # mailboxes with a null source and the queue could not find the source's
      # UPS webhook.
      :source_id,
      :designator,
      :user
    ])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:designator, :user])
  end
end
