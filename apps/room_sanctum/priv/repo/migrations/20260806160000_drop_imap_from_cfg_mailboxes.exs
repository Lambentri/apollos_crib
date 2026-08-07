defmodule RoomSanctum.Repo.Migrations.DropImapFromCfgMailboxes do
  use Ecto.Migration

  # Credentials moved to a first-class :mailbox source, so a single IMAP account
  # can be referenced by more than one consumer instead of being duplicated per
  # routing designator.
  def change do
    drop_if_exists index(:cfg_mailboxes, [:imap_host])

    alter table(:cfg_mailboxes) do
      remove :imap_host, :string
      remove :imap_port, :integer
      remove :imap_username, :string
      remove :imap_password, :string
      remove :imap_tls, :boolean
      remove :imap_folder, :string
      remove :imap_last_polled_at, :utc_datetime
      remove :imap_last_error, :string
    end
  end
end
