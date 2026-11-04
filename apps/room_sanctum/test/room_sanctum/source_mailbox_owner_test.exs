defmodule RoomSanctum.SourceMailboxOwnerTest do
  @moduledoc """
  A packages source is fed the mail its mailbox source pulls, so it may only
  name one of its owner's own -- naming someone else's would fan their mail
  out to it.
  """
  use RoomSanctum.DataCase

  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.Configuration

  defp mailbox_for(user) do
    source_for(user, %{
      type: :mailbox,
      config: %{
        "__type__" => "mailbox",
        "host" => "imap.e.test",
        "username" => "me",
        "password" => "pw"
      }
    })
  end

  defp packages(user, mailbox) do
    Configuration.create_source(%{
      name: "Parcels",
      notes: "",
      type: :packages,
      enabled: true,
      user_id: user.id,
      config: %{"__type__" => "packages", "mailbox_source_id" => mailbox.id}
    })
  end

  test "the owner's own mailbox is accepted" do
    me = owner()
    mailbox = mailbox_for(me)
    assert {:ok, source} = packages(me, mailbox)
    assert source.config.mailbox_source_id == mailbox.id
  end

  test "another user's mailbox is refused, as a changeset error" do
    assert {:error, changeset} = packages(owner(), mailbox_for(owner()))
    assert %{config: [_]} = errors_on(changeset)
  end

  test "an existing source cannot be moved onto another user's mailbox" do
    me = owner()
    {:ok, source} = packages(me, mailbox_for(me))
    theirs = mailbox_for(owner())

    assert {:error, _} =
             Configuration.update_source_config(source, %{mailbox_source_id: theirs.id})

    assert {:ok, _} = Configuration.update_source(source, %{name: "Renamed"})
    assert {:ok, _} = Configuration.update_source_config(source, %{handle_usps: false})
  end
end
