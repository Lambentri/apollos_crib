defmodule RoomSanctum.Configuration.Queries.Mailbox do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Show the latest messages in a mailbox.

  Read-only: listing fetches headers with `BODY.PEEK`, so looking at a mailbox
  never marks anything read and never competes with the poller's `\\Seen`
  bookkeeping.
  """

  embedded_schema do
    field :count, :integer, default: 10
    field :unread_only, :boolean, default: false
  end

  def changeset(source, params) do
    source
    |> cast(params, [:count, :unread_only])
    |> validate_required([:count])
    # A listing is a glance, not an archive; the cap keeps one query from
    # dragging a few thousand headers across on every refresh.
    |> validate_number(:count, greater_than: 0, less_than_or_equal_to: 100)
  end
end
